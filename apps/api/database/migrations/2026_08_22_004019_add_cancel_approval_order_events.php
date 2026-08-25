<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * İPTAL ONAY OLAYLARI — `order_events.event_type` CHECK kısıtı genişletildi (2026-08-22).
 *
 * ══ NEDEN GEREKLİ ══════════════════════════════════════════════════════════════════════════
 * `order_events.event_type` bir CHECK kısıtı taşır (migration 000207'de doğdu, 000401 ve
 * 000605'te iki kez genişletildi). Kısıtta olmayan bir olay türü INSERT anında **23514** ile
 * düşer ve senkron katmanı bunu istemci-kaynaklı geçersizlik sayıp olayı `rejected` döndürür.
 *
 * ⚠️ ARIZA SESSİZ DEĞİL AMA YANILTICIYDI ve ölçülerek bulundu: `EventValidator::OPS`e op
 * eklemek, `OrderChangeApplier`ın `match`ine dal eklemek ve mobil tarafı yazmak YETMEDİ —
 * yanıt `reason: "invalid_data"` diyordu, yani "kodun bir yerinde InvalidArgumentException".
 * Oysa istisna PHP'de değil POSTGRES'teydi. **Yeni bir sipariş olayı eklemenin DÖRDÜNCÜ yeri
 * budur ve listenin en kolay unutulanıdır.**
 *
 * ══ YENİ OLAYLAR ═══════════════════════════════════════════════════════════════════════════
 *  · `cancel_requested` — kurye iptal İSTER. Siparişin durumunu DEĞİŞTİRMEZ; `recomputeOrder`
 *    status'ü hâlâ yalnız `cancelled`/`delivered`tan türetir.
 *  · `cancel_rejected`  — yönetici reddeder. O da durumu değiştirmez.
 * Onayın ayrı bir olayı YOKTUR: onaylanan talep `cancelled` üretir, yani iptalin tek doğru
 * kaydı korunur.
 *
 * ══ GERİYE UYUM ════════════════════════════════════════════════════════════════════════════
 * Kısıtı GENİŞLETMEK geriye dönük uyumludur: mevcut satırların hepsi eski listede zaten
 * geçerli. `down()` daraltır ve bu, yeni olay YAZILMIŞSA başarısız olur — doğrusu da budur:
 * geri alma, veriyi sessizce geçersiz kılmak yerine gürültüyle durmalı.
 */
return new class extends Migration
{
    /**
     * ⚠️ LİSTE ELLE SAYILIR (000401/000605 deseni): migration bir TARİH KAYDIDIR ve yıllar
     * sonra da bugünkü şemayı üretmelidir. Uygulama sabitine (`EventValidator::OPS`) bağlamak,
     * listeye yarın eklenen bir op'un bu migration'ın geçmişini geriye dönük değiştirmesi
     * demekti — üstelik o liste TÜM varlıkların op'larını taşır, yalnız siparişinkileri değil.
     */
    private const YENI = "'created','line_added','line_removed','delivered','cancelled',".
        "'payment_set','note_set','assigned','unassigned','sort_set',".
        "'cancel_requested','cancel_rejected'";

    private const ESKI = "'created','line_added','line_removed','delivered','cancelled',".
        "'payment_set','note_set','assigned','unassigned','sort_set'";

    public function up(): void
    {
        DB::statement('ALTER TABLE order_events DROP CONSTRAINT order_events_type_check');
        DB::statement(
            'ALTER TABLE order_events ADD CONSTRAINT order_events_type_check '.
            'CHECK (event_type IN ('.self::YENI.'))'
        );
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE order_events DROP CONSTRAINT order_events_type_check');
        DB::statement(
            'ALTER TABLE order_events ADD CONSTRAINT order_events_type_check '.
            'CHECK (event_type IN ('.self::ESKI.'))'
        );
    }
};
