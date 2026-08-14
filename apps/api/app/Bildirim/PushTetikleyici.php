<?php

namespace App\Bildirim;

use App\Jobs\PushGonderimi;

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

        [$olay, $alici] = self::eslestir($tur, $op, $payload);

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
    private static function eslestir(string $tur, string $op, array $payload): array
    {
        // Sipariş bir kuryeye ATANDI → yalnız O kuryeye. Bu, push'un bu üründeki asıl varlık
        // sebebidir: kurye bugün siparişi ancak uygulamayı açıp senkronu bekleyerek görüyor.
        if ($tur === 'order' && $op === 'assigned') {
            $alici = isset($payload['assigned_user_id']) ? (string) $payload['assigned_user_id'] : null;

            return $alici === null ? [null, null] : [PushOlayi::SiparisAtandi, $alici];
        }

        // Teslim edildi → işi takip eden tarafa (yöneticiler). `unassigned` ve `cancelled`
        // BİLEREK DIŞARIDA: bunlar çoğunlukla yöneticinin KENDİ eylemidir; kendi dokunuşunun
        // bildirimini almak gürültüdür ve bayi bir süre sonra hepsini kapatır.
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
}
