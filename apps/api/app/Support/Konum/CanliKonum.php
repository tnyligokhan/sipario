<?php

namespace App\Support\Konum;

use Carbon\CarbonImmutable;

/**
 * Canlı listedeki TEK satır — deponun dış dünyaya verdiği biçim.
 *
 * Neden ham dizi değil: `toArray()` mobil ekiple anlaşılan sözleşmenin TEK yazıldığı yerdir.
 * Depo satırları serbest dizi döndürseydi alan adı/tip değişikliği sessizce sızar, ancak
 * istemci kırıldığında fark edilirdi.
 *
 * [tazeMi] kararı SUNUCUDA verilir ve burada taşınır (bkz. config/konum.php) — istemci saatine
 * göre yeniden hesaplamaz.
 *
 * KVKK (kırmızı çizgi #4): bu nesnede telefon/e-posta ALANI YOKTUR. Patronun haritada kimin
 * nerede olduğunu görmesi için ad ve rol yeter; iletişim bilgisi zaten ekibin listesinde vardır,
 * koordinatla aynı yanıtta birleştirilmesi için bir neden yok.
 *
 * Zaman alanı `Illuminate\Support\Carbon` DEĞİL, `CarbonImmutable`: readonly bir nesnede mutable
 * bir tarih tutmak yanıltıcıdır — `readonly` yeniden ATAMAYI engeller, nesnenin İÇİNİ değiştirmeyi
 * değil. `toArray()`teki `utc()` çağrısı mutable bir örnekte paylaşılan tarihi yerinde kaydırırdı.
 */
final readonly class CanliKonum
{
    public function __construct(
        public string $kullaniciId,
        public string $ad,
        public string $rol,
        public float $lat,
        public float $lng,
        public ?float $dogrulukM,
        public CarbonImmutable $bildirilme,
        public bool $tazeMi,
    ) {}

    /**
     * İstemci sözleşmesi. Zaman damgası ISO8601 UTC'dir — `server_time` ve senkron yanıtlarıyla
     * AYNI biçim (istemci tek bir ayrıştırıcı kullanır, yerel saate çevirmek onun işidir).
     *
     * @return array{user_id: string, name: string, role: string, lat: float, lng: float, accuracy_m: float|null, reported_at: string, is_fresh: bool}
     */
    public function toArray(): array
    {
        return [
            'user_id' => $this->kullaniciId,
            'name' => $this->ad,
            'role' => $this->rol,
            'lat' => $this->lat,
            'lng' => $this->lng,
            'accuracy_m' => $this->dogrulukM,
            'reported_at' => $this->bildirilme->utc()->toIso8601String(),
            'is_fresh' => $this->tazeMi,
        ];
    }
}
