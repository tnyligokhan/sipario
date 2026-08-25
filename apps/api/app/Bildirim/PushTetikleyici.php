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

        /*
         * KURYE İPTAL İSTEDİ → yöneticiler (kullanıcı isteği 2026-08-22).
         *
         * ALICI `null`DIR ve bu doğru: talebi kim karşılarsa karar onundur. Belirli bir kişiye
         * (ör. siparişi açan) yollamak, o kişi telefonuna bakmadığında kuryeyi müşterinin
         * kapısında cevapsız bırakırdı.
         *
         * TALEBİ AÇAN CİHAZ ZATEN ELENİR (`$cihaz` → `haricCihazId`): kendi eyleminin
         * bildirimini almazsın. Kurye aynı zamanda yönetici olsaydı bile kendi talebini
         * bildirim olarak görmezdi.
         */
        if ($tur === 'order' && $op === 'cancel_requested') {
            return [PushOlayi::SiparisIptalTalebi, null];
        }

        /*
         * TALEP REDDEDİLDİ → TALEBİ AÇAN kuryeye.
         *
         * ⚠️ ALICI PAYLOAD'DA YOK, olay geçmişinden okunur ([iptalIsteyeni]): reddin yükünde
         * kimin beklediği yazmaz, çünkü reddi yönetici gönderir ve o kuryenin kimliğini
         * taşımaz. Kimse bulunamazsa bildirim HİÇ DOĞMAZ — reddi rastgele birine göndermek,
         * hiç göndermemekten kötüdür.
         */
        if ($tur === 'order' && $op === 'cancel_rejected') {
            $alici = self::iptalIsteyeni($varlikId);

            return $alici === null ? [null, null] : [PushOlayi::SiparisIptalReddedildi, $alici];
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
    /**
     * REDDİN ALICISI: iptali İSTEYEN kurye (2026-08-22).
     *
     * Kaynak, EN SON `cancel_requested` olayının yükündeki `requested_by_user_id`. Sıralama
     * `iptalAlicisi` ve `deriveAssignedUserId` ile BİREBİR AYNI (`occurred_at DESC, id DESC`)
     * ve bu tesadüf değil: aynı sipariş için iki kez talep açılmış olabilir (ilki reddedildi,
     * kurye yeniden istedi) ve iki yer farklı sıralarsa ret, talebi açmayan kuryeye gider.
     *
     * `null` DÖNERSE bildirim doğmaz: talebi açan cihazda oturum kimliği inmemiş olabilir
     * (alan opsiyoneldir, bkz. `OrderChangeApplier::orderStatusEvent`).
     */
    private static function iptalIsteyeni(string $orderId): ?string
    {
        $sonTalep = OrderEvent::query()
            ->where('order_id', $orderId)
            ->where('event_type', 'cancel_requested')
            ->orderByDesc('occurred_at')
            ->orderByDesc('id')
            ->first();

        if ($sonTalep === null) {
            return null;
        }

        $payload = is_array($sonTalep->payload)
            ? $sonTalep->payload
            : json_decode((string) $sonTalep->payload, true);

        $userId = is_array($payload) ? ($payload['requested_by_user_id'] ?? null) : null;

        return is_string($userId) && $userId !== '' ? $userId : null;
    }

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
