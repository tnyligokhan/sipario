<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * KAPIDA İSKONTO — ledger_entries.entry_type CHECK'ine 'discount' eklenir
 * (kullanıcı isteği 2026-07-30: *"420 liralık siparişte 400 lira ödeme alınabilir;
 * 'borçlu gösterme' kutusu olması gerekiyor"*).
 *
 * NEDEN YENİ TİP, NEDEN 'payment' DEĞİL: kırılan 20 ₺ kasaya HİÇ girmedi. Onu payment yazsaydık
 * kasa her iskontoda şişer, bayi sayımda eksik bulur ve gün sonu farkı KANIT olmaktan çıkıp
 * gürültüye dönerdi (DECISIONS: "kasa kuruşuna kuruşuna", fark append-only kanıttır). 'discount'
 * `payment_type` TAŞIMAZ ve kasa değişmezi zaten "payment_type taşıyan kayıt kasaya dokundu"
 * olduğu için kasa sorgularının HİÇBİRİ değişmedi — yeni tip kasaya kendiliğinden girmiyor.
 *
 * NEDEN 'credit' DEĞİL: credit elle verilen alacaktır (iade/düzeltme) ve siparişe bağlı değildir;
 * iskontoyu onun içine karıştırmak "bu gün ne kadar kırdık" sorusunu SORULAMAZ hâle getirirdi.
 * Ayrı tip, gün sonundaki ayrı rakamın tek dayanağıdır.
 *
 * İşaret kısıtı UYGULAMADA (`ChangeApplier::validateLedgerEntry`): discount ≤ 0 — payment/credit
 * ile aynı yerde, aynı desende. CHECK burada yalnız tip KÜMESİNİ genişletir; mevcut satırların
 * hiçbiri etkilenmez, geri alma yolu da tam simetriktir.
 *
 * Migration owner (sipario_owner) ile koşar: `artisan migrate --database=pgsql_owner --force`.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE ledger_entries DROP CONSTRAINT ledger_entries_type_check');
        DB::statement(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_type_check '.
            "CHECK (entry_type IN ('debit','credit','payment','correction','discount'))"
        );
    }

    public function down(): void
    {
        // Geri alırken 'discount' satırı KALMIŞSA CHECK eklenemez ve migration haklı olarak düşer:
        // kayıt silerek yol açmak append-only'yi (kırmızı çizgi #2) kırardı.
        DB::statement('ALTER TABLE ledger_entries DROP CONSTRAINT ledger_entries_type_check');
        DB::statement(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_type_check '.
            "CHECK (entry_type IN ('debit','credit','payment','correction'))"
        );
    }
};
