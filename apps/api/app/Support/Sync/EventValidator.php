<?php

namespace App\Support\Sync;

use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Throwable;

/**
 * Bir push olayının İÇERİK doğrulaması — olay bazında, parti düşürmeden (2026-08-05 saha arızası).
 *
 * NEDEN BU SINIF VAR: bu kurallar `SyncPushRequest` içinde `events.*.…` biçimindeydi ve orada
 * PARTİ DÜZEYİNDE çalışıyordu — TEK bozuk olay isteğin tamamını 422 yapıyordu. İstemci 422'de
 * hiçbir olayı işaretleyemez (sync_engine `api.push()` fırlatınca outbox'a dokunmaz), sonraki turda
 * AYNI partiyi yollar ve aynı 422'yi alır: kuyruk asla boşalmaz, telefon KALICI ÇEVRİMDIŞI kalır.
 * Tek çözüm uygulama verisini temizlemekti — ki bu outbox'ı da siler, yani gönderilmemiş sipariş ve
 * tahsilat kaybolur (BRIEF kırmızı çizgi #3 ihlali). Somut vaka: `coupon` 2026-07-26'da
 * ENTITY_TYPES'tan çıkarıldı; kuyruğunda kupon olayı kalmış her cihaz o günden beri kilitliydi.
 *
 * Kural şimdi şu: ZARF (events var mı / dizi mi / boş mu / tavanı aştı mı) istekte doğrulanır ve
 * 422 verir — o bir protokol hatasıdır, tekrar denemek çözmez ve işaretlenecek bir olay da yoktur.
 * OLAY İÇERİĞİ burada doğrulanır ve bozuk olay `rejected` döner; parti 200 ile akmaya devam eder.
 *
 * ÖNEMLİ: doğrulama HER ŞEYDEN ÖNCE koşar, çünkü geçersiz bir `client_event_id` ile yapılan
 * `processed_events` sorgusu Postgres'te 22P02 verir ve o hata savepoint DIŞINDA olduğu için TÜM
 * transaction'ı zehirlerdi (500 + zehirli hap). Aynısı geçersiz `occurred_at` için de geçerliydi:
 * kilitli bayide `Carbon::parse` try bloğunun dışında çağrılıyordu.
 *
 * Sözlük buraya taşındığında listeden bir tip/op ÇIKARMAK artık cihaz kilitlemez: eski kuyruklarda
 * kalan olaylar per-olay reddedilir, istemci onları karantinaya alır ve kuyruk boşalır.
 */
final class EventValidator
{
    /** Sunucunun tanıdığı varlıklar (`coupon` 2026-07-26'da çıkarıldı). */
    public const ENTITY_TYPES = [
        'customer', 'customer_phone', 'customer_address', 'product', 'order', 'ledger',
        'cash_handover', 'tenant_settings', 'exempt_number', 'call_log', 'day_closing', 'user_profile',
    ];

    /**
     * Tanınan op'lar (kupona ait `grant`/`use` çıkarıldı). Defterin `correction`ı bir OP DEĞİL
     * `entry_type` payload alanıdır (op'u `entry`dir) — o yüzden burada yoktur.
     *
     * Bu liste KABA bir süzgeçtir: hangi op'un hangi varlıkta geçerli olduğunu ChangeApplier ve
     * alt uygulayıcıları bilir ve geçersizini InvalidArgumentException ile reddeder (yine per-olay).
     */
    public const OPS = [
        'upsert', 'delete', 'created', 'line_added', 'line_removed', 'delivered', 'cancelled',
        'payment_set', 'note_set', 'assigned', 'unassigned', 'sort_set', 'entry', 'handover', 'closing',
        // İPTAL ONAY AKIŞI (2026-08-22): kurye iptal İSTER, yönetici onaylar ya da reddeder.
        // Onay ayrı bir op DEĞİLDİR — iptalin tek kaydı `cancelled`tır; ikinci bir "approved"
        // olayı, siparişin durumunu türeten iki ayrı kural demekti.
        //
        // ⚠️ YENİ BİR SİPARİŞ OLAYI EKLERKEN BU LİSTE DÖRTTE BİRİDİR ve dördüncüsü en kolay
        // unutulanıdır (2026-08-22'de ölçülerek bulundu): (1) burası, (2) `OrderChangeApplier`
        // `match` dalı, (3) mobil taraf, (4) **`order_events.event_type` CHECK kısıtı**.
        // Dördüncüsü eksikse olay PHP'den geçer, POSTGRES 23514 ile düşer ve yanıt
        // `reason: "invalid_data"` der — yani hata koda bakarken aranır, oysa şemadadır.
        'cancel_requested', 'cancel_rejected',
    ];

    /**
     * Olayın reddedilme sebebi (kod); olay geçerliyse null.
     *
     * @param  array<mixed, mixed>  $event
     */
    public static function reason(array $event): ?string
    {
        $clientEventId = $event['client_event_id'] ?? null;
        if (! is_string($clientEventId) || $clientEventId === '') {
            return 'missing_client_event_id';
        }
        if (! Str::isUuid($clientEventId)) {
            return 'invalid_client_event_id';
        }

        $entityType = $event['entity_type'] ?? null;
        if (! is_string($entityType) || ! in_array($entityType, self::ENTITY_TYPES, true)) {
            return 'unknown_entity_type';
        }

        $op = $event['op'] ?? null;
        if (! is_string($op) || ! in_array($op, self::OPS, true)) {
            return 'unknown_op';
        }

        // occurred_at LWW'nin ve kilit kararının dayanağıdır; ayrıca sync_changes'e ham yazılır.
        // Carbon çözemiyorsa Postgres de çözemez — burada reddedilir, aşağıda patlamaz.
        $occurredAt = $event['occurred_at'] ?? null;
        if (! is_string($occurredAt) || trim($occurredAt) === '' || ! self::cozulebilir($occurredAt)) {
            return 'invalid_occurred_at';
        }

        // `required|array` ile aynı anlam: dizi VE boş değil (boş payload hiçbir varlığı yazamaz).
        $payload = $event['payload'] ?? null;
        if (! is_array($payload) || $payload === []) {
            return 'invalid_payload';
        }

        // device_id opsiyoneldir (nullable) ama verilmişse uuid olmalı: sync_changes.device_id
        // uuid kolonudur, geçersiz değer 22P02 üretir.
        $deviceId = $event['device_id'] ?? null;
        if ($deviceId !== null && (! is_string($deviceId) || ! Str::isUuid($deviceId))) {
            return 'invalid_device_id';
        }

        return null;
    }

    /**
     * Yanıtta geri yansıtılacak `client_event_id` — HAM DEĞER, olduğu gibi.
     *
     * KRİTİK: istemci sonuçları `client_event_id` ile eşler (sync_engine `byId` haritası). Geçersiz
     * bir kimliği normalize etseydik ya da boşaltsaydık istemci o outbox satırını EŞLEŞTİREMEZ ve
     * satır sonsuza dek `pending` kalırdı — düzeltmeye çalıştığımız arızanın aynısı. Bu yüzden
     * kırpma/temizleme YOKTUR; skaler olmayan değer (dizi/nesne) için '' döner, o durumda istemci
     * indeks alanına düşer (bkz. results.index).
     */
    public static function clientEventId(mixed $event): string
    {
        if (! is_array($event)) {
            return '';
        }

        $raw = $event['client_event_id'] ?? null;

        return is_scalar($raw) ? (string) $raw : '';
    }

    /** Sebep kodunun kullanıcıya gösterilebilir karşılığı (KVKK: sabit metin, payload yansıtılmaz). */
    public static function message(string $reason): string
    {
        return match ($reason) {
            'invalid_event' => 'Olay biçimi geçersiz.',
            'missing_client_event_id' => 'Olay kimliği eksik.',
            'invalid_client_event_id' => 'Olay kimliği geçersiz.',
            'unknown_entity_type' => 'Bu kayıt türü artık desteklenmiyor.',
            'unknown_op' => 'Bu işlem türü desteklenmiyor.',
            'invalid_occurred_at' => 'Olay zamanı geçersiz.',
            'invalid_payload' => 'Olay içeriği geçersiz.',
            'invalid_device_id' => 'Cihaz kimliği geçersiz.',
            default => 'Kayıt reddedildi (geçersiz veri).',
        };
    }

    private static function cozulebilir(string $value): bool
    {
        try {
            Carbon::parse($value);

            return true;
        } catch (Throwable) {
            return false;
        }
    }
}
