<?php

namespace App\Bildirim;

use App\Enums\UserRole;
use App\Models\Device;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

/**
 * "KİME GİDECEK" SORUSUNUN TEK CEVABI. Düşük seviye HTTP işi `FcmIstemcisi`'nde; burada
 * yalnız alıcı seçimi, ölü jeton temizliği ve kişisel veri kapısı vardır.
 *
 * ⚠️ OKUMA `pgsql_owner` İLE YAPILIR ve bu pazarlıksızdır. Bu kod KUYRUKTAN koşar; orada
 * RLS'in kiracı değişkeni KURULU DEĞİLDİR ve normal `pgsql` bağlantısı boş küme döndürür.
 * Arıza tamamen sessiz olurdu: hata çıkmaz, push gitmez, kimse fark etmez. Aynı tuzağa
 * `BayiPostacisi` de aynı gerekçeyle karşı korunmuştur.
 *
 * KİRACI İZOLASYONU (kırmızı çizgi #1) BURADA ELLE ZORLANIR: RLS devre dışı olduğu için
 * her sorgu `where('tenant_id', ...)` taşır. Bir bayinin olayı başka bayinin telefonuna
 * düşerse bu, veri sızıntısının en görünür biçimidir.
 */
class PushGondericisi
{
    public function __construct(private readonly FcmIstemcisi $istemci) {}

    /**
     * Olayı ilgili cihazlara gönderir. Gönderilen cihaz sayısını döndürür.
     *
     * @param  string|null  $aliciUserId  Belirli bir kişiye gidecekse (sipariş atama). null ise yöneticiler.
     * @param  string|null  $haricCihazId  Olayı ÜRETEN cihaz — kendi eylemin için bildirim almazsın.
     */
    public function gonder(
        string $tenantId,
        PushOlayi $olay,
        string $varlikId,
        ?string $aliciUserId = null,
        ?string $haricCihazId = null,
    ): int {
        if (! $this->istemci->kurulu()) {
            return 0;
        }

        $cihazlar = $this->cihazlar($tenantId, $aliciUserId, $haricCihazId);
        if ($cihazlar->isEmpty()) {
            return 0;
        }

        /*
         * YÜKÜN TAMAMI BU ÜÇ ALANDIR. Müşteri adı, adres, tutar — hiçbiri eklenemez
         * (BRIEF kırmızı çizgi #4: kişisel veri Google'ın sunucularından geçmez). Metni
         * telefon kendi veritabanından üretir.
         *
         * `kategori` yükte taşınır ki telefon, bayinin o kategoriyi kısıp kısmadığına
         * senkronu koşturduktan SONRA baksın: bildirim çizilmese de veri gelmelidir.
         */
        $veri = [
            'olay' => $olay->value,
            'id' => $varlikId,
            'kategori' => $olay->kategori(),
        ];

        $gonderilen = 0;

        foreach ($cihazlar as $cihaz) {
            $sonuc = $this->istemci->gonder((string) $cihaz->push_token, $veri);

            match ($sonuc) {
                PushSonucu::Basarili => $gonderilen++,
                PushSonucu::JetonOlu => $this->jetonuSil($cihaz),
                PushSonucu::Gecici, PushSonucu::Kalici, PushSonucu::Kapali => null,
            };
        }

        return $gonderilen;
    }

    /**
     * Alıcı cihazlar: jetonu OLAN, aktif kullanıcıya ait, olayı üretmemiş cihazlar.
     *
     * @return Collection<int,Device>
     */
    private function cihazlar(string $tenantId, ?string $aliciUserId, ?string $haricCihazId)
    {
        $sorgu = Device::on('pgsql_owner')
            ->where('tenant_id', $tenantId)
            ->whereNotNull('push_token');

        if ($haricCihazId !== null) {
            $sorgu->where('id', '!=', $haricCihazId);
        }

        if ($aliciUserId !== null) {
            $sorgu->where('user_id', $aliciUserId);
        } else {
            $sorgu->whereIn('user_id', $this->yoneticiIdleri($tenantId));
        }

        return $sorgu->get();
    }

    /**
     * Bayinin yöneticileri: patron + operatör. Kurye HARİÇ — "teslim edildi" ve "kasa
     * devredildi" olayları işi TAKİP EDEN tarafa aittir; kuryenin kendi teslimini kendisine
     * bildirmek gürültüdür ve bayi bir süre sonra bütün bildirimleri kapatır.
     *
     * @return array<int,string>
     */
    private function yoneticiIdleri(string $tenantId): array
    {
        return User::on('pgsql_owner')
            ->where('tenant_id', $tenantId)
            ->whereIn('role', [UserRole::Patron->value, UserRole::Operator->value])
            ->where('status', 'active')
            ->pluck('id')
            ->all();
    }

    /**
     * Ölü jetonu temizler. `push_token = null` yazılır, CİHAZ KAYDI SİLİNMEZ: cihaz listesi
     * bayinin güvenlik ekranıdır ("hesabım hangi telefonlarda açık"), oradan bir satırın
     * bildirim jetonu öldü diye kaybolması yanlış bilgi verirdi.
     */
    private function jetonuSil(Device $cihaz): void
    {
        Device::on('pgsql_owner')
            ->where('id', $cihaz->id)
            ->update(['push_token' => null]);

        Log::info('Push jetonu ölü, temizlendi', ['device_id' => $cihaz->id]);
    }
}
