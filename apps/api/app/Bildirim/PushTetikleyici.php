<?php

namespace App\Bildirim;

use App\Jobs\PushGonderimi;
use App\Models\Order;
use App\Models\OrderEvent;

/**
 * "HANGİ SENKRON OLAYI PUSH DOĞURUR" SORUSUNUN TEK YERİ.
 *
 * NEDEN APPLIER'LARIN İÇİNDE DEĞİL: kural applier'lara dağılsaydı her yeni olay türünde
 * "buraya da push eklenecek mi?" sorusu yeniden sorulurdu ve biri mutlaka unutulurdu. Burada
 * tek bir `match` var; listeye bakan, sistemin telefonlara ne gönderdiğini bir bakışta görür.
 *
 * ÇAĞRILDIĞI YER `SyncService::push` — olay UYGULANDIKTAN sonra, transaction İÇİNDE. Bu yüzden
 * iş kuyruğa `afterCommit` ile atılır: transaction geri alınırsa var olmayan bir siparişin
 * bildirimi telefonlara düşmemelidir.
 */
class PushTetikleyici
{
    /**
     * @param  array<string,mixed>  $event  İstemciden gelen ham senkron olayı.
     * @param  array<string,mixed>  $result  `applyOne` sonucu (status · entity_id).
     */
    public static function olayUygulandi(string $tenantId, array $event, array $result): void
    {
        /*
         * YALNIZ 'applied'. `stale` (eski damga, uygulanmadı), `noop`, `duplicate` (aynı olay
         * ikinci kez geldi — offline istemci yeniden denemesi NORMALDİR) push doğurmaz. Bunu
         * atlamak, ağı zayıf bir kuryenin her yeniden denemesinde patronun telefonunu
         * öttürürdü.
         */
        if (($result['status'] ?? '') !== 'applied') {
            return;
        }

        $tur = (string) ($event['entity_type'] ?? '');
        $op = (string) ($event['op'] ?? '');
        /** @var array<string,mixed> $payload */
        $payload = (array) ($event['payload'] ?? []);
        $varlikId = (string) ($result['entity_id'] ?? '');
        $cihaz = isset($event['device_id']) ? (string) $event['device_id'] : null;

        if ($varlikId === '') {
            return;
        }

        [$olay, $alici] = self::eslestir($tur, $op, $payload, $varlikId);

        if ($olay === null) {
            return;
        }

        PushGonderimi::dispatch($tenantId, $olay, $varlikId, $alici, $cihaz)->afterCommit();
    }

    /**
     * Olay eşleştirme. Yeni bir push olayı eklemenin TEK yeri burasıdır.
     *
     * @param  array<string,mixed>  $payload
     * @return array{0: PushOlayi|null, 1: string|null} [olay, belirli alıcı (null = yöneticiler)]
     */
    private static function eslestir(string $tur, string $op, array $payload, string $varlikId): array
    {
        // Sipariş bir kuryeye ATANDI → yalnız O kuryeye. Bu, push'un bu üründeki asıl varlık
        // sebebidir: kurye bugün siparişi ancak uygulamayı açıp senkronu bekleyerek görüyor.
        if ($tur === 'order' && $op === 'assigned') {
            $alici = isset($payload['assigned_user_id']) ? (string) $payload['assigned_user_id'] : null;

            return $alici === null ? [null, null] : [PushOlayi::SiparisAtandi, $alici];
        }

        /*
         * İPTAL ya da ATAMA GERİ ALINDI → o ana kadar ATANMIŞ olan kuryeye (kullanıcı kararı
         * 2026-08-14). Kurye yola çıkmış olabilir ve bugün bunu ancak uygulamayı açarak görüyor.
         *
         * ⚠️ ALICI PAYLOAD'DA YOK, TÜRETİLİR — ve iki op'ta iki farklı yerden:
         *   `cancelled`  : iptal atamayı silmez, `orders.assigned_user_id` yerinde durur.
         *   `unassigned` : atama SİLİNMİŞTİR (bu çağrı olay uygulandıktan SONRA geliyor), yani
         *                  önbelleğe bakmak `null` verir; kimi uyaracağımızı olay geçmişinden
         *                  okumak zorundayız.
         * Bu yüzden alıcı çözümlemesi `iptalAlicisi`ndedir; oraya bakmadan buradaki dalın
         * neden iki ayrı yol izlediği anlaşılmaz.
         */
        if ($tur === 'order' && ($op === 'cancelled' || $op === 'unassigned')) {
            $alici = self::iptalAlicisi($op, $varlikId);

            return $alici === null ? [null, null] : [PushOlayi::SiparisIptal, $alici];
        }

        // Teslim edildi → işi takip eden tarafa (yöneticiler).
        if ($tur === 'order' && $op === 'delivered') {
            return [PushOlayi::SiparisTeslim, null];
        }

        /*
         * Kasa devri → yöneticiler. TERS KAYIT (iptal) HARİÇ: `reverses_handover_id` dolu satır
         * bir devir değil, bir devrin iptalidir; "kurye kasayı devretti" bildirimi göndermek
         * gerçeğin tersini söylerdi. İptali zaten yönetici yapar (2026-08-13: üç para eylemi
         * `gunuKapatma` yetkisine bağlandı), yani kendi eyleminin bildirimi olurdu.
         *
         * `isset` TEK BAŞINA YETER ve doğru olan da budur: alanı açıkça `null` göndermek
         * "ters kayıt değil" demektir ve `isset` onu zaten eler. Boş dize gibi bozuk bir
         * değer buraya HİÇ ULAŞAMAZ — `CashHandoverChangeApplier` onu doğrulayamayıp olayı
         * reddeder, biz ise yalnız `applied` olayları görürüz.
         */
        if ($tur === 'cash_handover' && $op === 'handover') {
            $tersMi = isset($payload['reverses_handover_id']);

            return $tersMi ? [null, null] : [PushOlayi::KasaDevri, null];
        }

        return [null, null];
    }

    /**
     * İptal/geri alma bildiriminin ALICISI: o ana kadar siparişe atanmış kurye.
     *
     * `cancelled` — iptal atamayı silmez; `orders.assigned_user_id` önbelleği hâlâ doğrudur.
     *
     * `unassigned` — atama önbelleği bu noktada zaten SİLİNMİŞTİR (`recomputeOrder` olaydan
     * türetip `null` yazdı). Kimi uyaracağımız yalnız olay geçmişinde durur: son `assigned`
     * olayının yükündeki kullanıcı. Sıralama `OrderChangeApplier::deriveAssignedUserId` ile
     * BİREBİR AYNI (`occurred_at DESC, id DESC`) ve bu tesadüf değil — iki yer farklı sıralarsa
     * bildirim, siparişi gerçekten üstlenmiş kuryeden BAŞKASINA gider.
     *
     * `null` dönerse bildirim hiç doğmaz: atanmamış bir siparişin iptalini kimseye haber
     * vermek gerekmez.
     */
    private static function iptalAlicisi(string $op, string $orderId): ?string
    {
        if ($op === 'cancelled') {
            $order = Order::query()->find($orderId);

            return $order?->assigned_user_id;
        }

        $sonAtama = OrderEvent::query()
            ->where('order_id', $orderId)
            ->where('event_type', 'assigned')
            ->orderByDesc('occurred_at')
            ->orderByDesc('id')
            ->first();

        if ($sonAtama === null) {
            return null;
        }

        $payload = is_array($sonAtama->payload)
            ? $sonAtama->payload
            : json_decode((string) $sonAtama->payload, true);

        $userId = is_array($payload) ? ($payload['assigned_user_id'] ?? null) : null;

        return is_string($userId) && $userId !== '' ? $userId : null;
    }
}
