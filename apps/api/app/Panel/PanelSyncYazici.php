<?php

namespace App\Panel;

use App\Models\User;
use App\Support\Sync\SyncService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Panelden İŞ VERİSİ YAZAN servislerin ortak temeli (5c-3). Tek tek kayıt yazan
 * `PanelWriteService` ile toplu aktarım yapan `PanelImportService` bu sınıfı paylaşır — yazma
 * yolunun kuralları TEK yerde durmalı, iki kopya kaçınılmaz olarak ayrışırdı.
 *
 * ÜÇ KURAL, üçü de bilinçli:
 *
 *  1. YAZMA `sipario_panel` ROLÜYLE YAPILMAZ. O rolün iş tablolarında INSERT/UPDATE grant'i yoktur
 *     (migration 504) ve BU KORUNUYOR — panelin salt-okunurluğu hâlâ DB izniyle zorlanıyor. Yazma,
 *     bayinin kendi API'sinin kullandığı RLS'li `pgsql` bağlantısıyla ve `app.tenant_id` bağlamı
 *     kurularak yapılır: yani panel, bayinin kapısından girer, arka kapıdan değil.
 *
 *  2. ELLE SQL YAZILMAZ. Kayıt, mobilin kullandığı AYNI yoldan geçer: SyncService::push →
 *     ChangeApplier. Böylece LWW damgası, tombstone kuralı, sıra kodu ataması, idempotency defteri
 *     ve en önemlisi `sync_changes` seq'i kendiliğinden doğar — panelden girilen müşteri cihazlara
 *     düşer. İkinci bir yazma yolu açmak bu davranışların ikinci (ve bayatlayacak) bir kopyasını
 *     kurmak olurdu.
 *
 *  3. HER YAZMA `panel_audit`e kayıt bırakır (panel bağlantısıyla, INSERT grant'i orada).
 *
 * ABONELİK KİLİDİ PANELİ DE BAĞLAR: push kilitli bayide 'locked' döner ve panel de yazamaz. Bu
 * kasıtlıdır — kilit kararının tek sahibi sunucudur; paneli muaf tutmak "kilitli" kavramını
 * bayiye göre değişen bir şeye çevirirdi. Destek önce denemeyi uzatır/aboneliği açar, sonra girer.
 */
abstract class PanelSyncYazici
{
    /** RLS'e tabi uygulama bağlantısı — yazmalar buradan geçer (panel rolü DEĞİL). */
    protected const APP = 'pgsql';

    /**
     * Panel yazmalarının sentetik cihaz kimliği. GERÇEK BİR CİHAZ DEĞİLDİR ve `devices` tablosuna
     * satır yazmaz — hiçbir kolonda device_id üzerinde FK yoktur, bu alan yalnız LWW meta'sıdır.
     *
     * Neden sabit ve neden 'ffff…': LWW eşitliği `device_id` metin karşılaştırmasıyla çözer; bu
     * değer her gerçek UUIDv7'den büyüktür, yani panel aynı saniyedeki bir cihaz yazımıyla
     * berabere kalmaz. Rastgele bir kimlik seçseydik sonuç yazı-tura olurdu (bu depoda uuid7'nin
     * aynı ms içinde sırasızlığı zaten bir kez ürün hatası doğurdu — belirsizliği tekrarlamıyoruz).
     */
    public const PANEL_DEVICE_ID = 'ffffffff-ffff-ffff-ffff-ffffffffffff';

    public function __construct(protected readonly string $panelConnection = 'pgsql_panel') {}

    /**
     * Verilen işi, bayinin RLS bağlamı kurulmuş `pgsql` bağlantısında koşar.
     *
     * `set_config(..., true)` LOCAL'dir, yani TRANSACTION ömrü kadar yaşar — bu yüzden iş tek bir
     * transaction'a sarılır ve bittiğinde bağlam kendiliğinden sıfırlanır (ResolveTenantContext'in
     * API tarafında yaptığının aynısı; kalıcı bağlantıda tenant sızıntısı olmaz).
     *
     * Varsayılan bağlantı geçici olarak `pgsql`e alınır (Provisioning::asOwner deseni): Eloquent
     * modelleri bağlantıyı varsayılandan çözer, `set_config`i bir bağlantıda yapıp modeli başka
     * bağlantıda çalıştırmak sessizce RLS-bağlamsız (yani sıfır satır gören) bir sorgu üretirdi.
     *
     * @template T
     *
     * @param  callable():T  $is
     * @return T
     */
    protected function rlsIcinde(string $tenantId, callable $is): mixed
    {
        $onceki = DB::getDefaultConnection();
        DB::setDefaultConnection(self::APP);

        try {
            return DB::connection(self::APP)->transaction(function () use ($tenantId, $is) {
                DB::connection(self::APP)->statement("SELECT set_config('app.tenant_id', ?, true)", [$tenantId]);

                return $is();
            });
        } finally {
            DB::setDefaultConnection($onceki);
        }
    }

    /**
     * Olayları senkron çekirdeğine verir. Aktör olarak bayinin PATRONU seçilir: push yalnız
     * `tenant_id`yi kullanır ama olayın bir kullanıcıya bağlı olması gerekir ve panel eyleminin
     * bayi tarafındaki en doğru karşılığı hesabın sahibidir. Kimlik RLS altında çözülür — başka
     * bayinin kullanıcısı buraya gelemez.
     *
     * `device_id` sentetik PANEL_DEVICE_ID'dir (bkz. sabit). Pull cevabı değişiklik başına device_id
     * TAŞIMAZ, dolayısıyla panelden girilen kayıt istisnasız TÜM cihazlara düşer.
     *
     * @param  list<array<string, mixed>>  $olaylar
     * @return array<string, mixed>
     */
    protected function push(string $tenantId, array $olaylar): array
    {
        /** @var User|null $aktor */
        $aktor = User::query()->where('tenant_id', $tenantId)
            ->orderByRaw("case when role = 'patron' then 0 else 1 end")
            ->first();

        if ($aktor === null) {
            throw new RuntimeException('Bu bayide kullanıcı yok; panelden veri girilemez.');
        }

        return (new SyncService)->push($aktor, $olaylar);
    }

    /**
     * Bir müşterinin BİRİNCİL alt kaydı (telefon/adres). Varsa o satır güncellenir; yoksa null
     * döner ve çağıran yeni bir kimlik üretir. Bu olmadan her kayıtta yeni bir telefon/adres satırı
     * doğar, müşterinin altında yığılırdı.
     *
     * @param  class-string<Model>  $sinif
     */
    protected function birincilKayit(string $sinif, string $customerId): mixed
    {
        return $sinif::query()
            ->where('customer_id', $customerId)
            ->whereNull('deleted_at')
            ->orderByDesc('is_primary')
            ->first();
    }

    /**
     * Olayın LWW damgası — ve bu depodaki en ince tuzaklardan biri.
     *
     * SORUN: `updated_occurred_at` `timestamp(0)`dır (saniye çözünürlüğü) ve ChangeApplier'ın LWW
     * kuralı eşitlikte `device_id` karşılaştırmasına düşer. Aynı saniyeye düşen iki PANEL yazması
     * hem damgada hem cihazda berabere kalır → ikincisi 'stale' işaretlenir ve UYGULANMAZ. Sahada:
     * destek müşteriyi kaydeder, hemen düzeltir, düzeltme sessizce kaybolur.
     *
     * ÇÖZÜM İKİ PARÇALI ve ikisi de DAR kapsamlıdır:
     *
     *  (a) Panel yazmaları sabit bir sentetik cihaz kimliği taşır (PANEL_DEVICE_ID). Böylece panel
     *      ile bir CİHAZ aynı saniyede yazarsa berabere kalınmaz: kimlik karşılaştırması panelin
     *      lehine sonuçlanır. İnsanın panelde bilerek yaptığı düzeltmenin, aynı saniyedeki bir
     *      cihaz yazımını ezmesi doğru önceliktir.
     *
     *  (b) Damga yalnız PANELİN KENDİ önceki damgasının üstüne çıkar. Ezilecek satırı en son bir
     *      CİHAZ yazdıysa damga ASLA ileri alınmaz — o zaman LWW doğal işini yapar ve gerçekten
     *      daha yeni olan cihaz yazımı korunur, panele 'stale' döner (durumOzeti bunu söyler).
     *
     * Bu ayrım kritiktir: koşulsuz ileri alma, panelin cihazın DAHA YENİ verisini sessizce ezmesi
     * demekti — ilk yazılan hâli buydu ve testte yakalandı. Şimdi ileri alma yalnız kendi
     * biriktirdiğimiz saniye kaymasını aşar, başkasının kararını değil.
     *
     * @param  list<Model|null>  $mevcutlar
     */
    protected function damga(array $mevcutlar): string
    {
        // startOfSecond ŞART: damga birazdan toIso8601String() ile saniyeye yuvarlanacak ve kolon
        // da `timestamp(0)`. Karşılaştırmayı saniye-altı bir `now()` ile yapmak "12:00:05 >= 12:00:05.9"
        // gibi yanlış bir soru sorar, ileri alma tetiklenmez ve yazım sessizce bayat kalır.
        $damga = now()->startOfSecond();

        foreach ($mevcutlar as $mevcut) {
            if ($mevcut === null) {
                continue;
            }
            if ((string) $mevcut->getAttribute('updated_device_id') !== self::PANEL_DEVICE_ID) {
                continue; // cihaz yazımı — LWW'ye dokunma
            }

            $onceki = $mevcut->getAttribute('updated_occurred_at');
            if ($onceki !== null && $onceki->greaterThanOrEqualTo($damga)) {
                $damga = $onceki->copy()->addSecond();
            }
        }

        return $damga->toIso8601String();
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    protected function olay(string $tip, string $op, array $payload, ?string $occurredAt = null): array
    {
        return [
            'client_event_id' => (string) Str::uuid7(),
            'entity_type' => $tip,
            'op' => $op,
            'occurred_at' => $occurredAt ?? now()->toIso8601String(),
            'device_id' => self::PANEL_DEVICE_ID,
            'payload' => $payload,
        ];
    }

    /**
     * Push sonucunu tek duruma indirger: bir olay bile kilitli/reddedilmiş/BAYAT ise sonuç odur.
     *
     * 'stale' bilerek BAŞARISIZ sayılır. ChangeApplier bayat olayı sessizce yutar (mobilde doğrudur:
     * çevrimdışı cihazın eski yazımı zaten kaybetmelidir) ama panelde kullanıcı formu az önce
     * doldurdu — "kaydedildi" deyip hiçbir şey yazmamak panelin söyleyebileceği en kötü yalandır.
     *
     * @param  array<string, mixed>  $push
     * @return array{durum: string, mesaj: string|null}
     */
    protected function durumOzeti(array $push): array
    {
        foreach (['locked', 'rejected', 'stale'] as $kotu) {
            foreach ($push['results'] as $sonuc) {
                if (($sonuc['status'] ?? '') === $kotu) {
                    return [
                        'durum' => $kotu,
                        'mesaj' => $sonuc['message'] ?? ($kotu === 'stale'
                            ? 'Bu kayıt daha yeni bir değişiklikle güncellenmiş; sayfayı tazeleyip tekrar deneyin.'
                            : null),
                    ];
                }
            }
        }

        return ['durum' => 'applied', 'mesaj' => null];
    }

    /** Denetim kaydı panel bağlantısıyla (panel_audit INSERT grant'i orada; KVKK: değer yazılmaz). */
    protected function audit(?string $adminId, string $tenantId, string $action, ?string $detail = null): void
    {
        DB::connection($this->panelConnection)->table('panel_audit')->insert([
            'id' => (string) Str::uuid7(),
            'admin_user_id' => $adminId,
            'tenant_id' => $tenantId,
            'action' => $action,
            'detail' => $detail,
            'created_at' => now(),
        ]);
    }

    protected function bosNull(?string $deger): ?string
    {
        $deger = trim((string) $deger);

        return $deger === '' ? null : $deger;
    }
}
