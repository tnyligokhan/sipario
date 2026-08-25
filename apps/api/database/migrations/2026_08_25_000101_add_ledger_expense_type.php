<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * SAHA GİDERİ — `ledger_entries.entry_type` kümesine 'expense' eklenir (kullanıcı isteği
 * 2026-08-25: *"Gün Özeti'nde Gider Ekleme özelliği de olmalı"*).
 *
 * ══ NEDEN YENİ TABLO DEĞİL ══════════════════════════════════════════════════════════════════
 * Gider bir PARA HAREKETİDİR ve bu üründe para hareketleri `ledger_entries`tedir. Yeni bir tablo;
 * yeni bir senkron `op`u, yeni bir RLS ilkesi, yeni bir çakışma kuralı ve — en pahalısı — kasa
 * mutabakatının İKİNCİ bir kaynağı demekti. Defter satırı olduğunda kuryenin cebindeki para,
 * günün kasası ve kapanış beklentisi gideri KENDİLİĞİNDEN görür.
 *
 * ══ NEDEN payment_type ZORUNLU (ve YALNIZ 'nakit') ══════════════════════════════════════════
 * Kasa değişmezi "payment_type taşıyan kayıt = kasaya dokundu"dur (DECISIONS Faz 3). Gider
 * taşımasaydı kasa sorguları onu HİÇ görmez, kasadan çıkan para görünmez bir kayda dönerdi —
 * yani özelliğin tek amacı boşa çıkardı. Bu yüzden `payment_type` KAPSAM kısıtına da eklenir.
 *
 * v1'de gider yalnız NAKİTTİR ve kural uygulamada (`ChangeApplier::validateLedgerEntry`) durur:
 * bu ekranın sorusu "çekmecede ne kalmalı"dır ve karttan ödenen bir masraf çekmeceye dokunmaz.
 * Kâr-zarar defteri ayrı bir iştir; burada başlatılmaz.
 *
 * ══ İŞARET ve MÜŞTERİ ═══════════════════════════════════════════════════════════════════════
 * `amount_kurus` POZİTİF (kasadan çıkan), iptalinde NEGATİF — iptal, ters işaretli İKİNCİ bir
 * 'expense' satırıdır (`reverses_entry_id` dolu). BRIEF kırmızı çizgi #2: para kayıtları
 * silinmez/ezilmez.
 *
 * `customer_id` NULL OLMAK ZORUNDA (uygulama kapısı): tüm entry_type'lar borç-deltası taşır ve
 * dolu bir müşteriyle yazılan gider, o müşterinin bakiyesini benzin parası kadar ŞİŞİRİRDİ.
 *
 * ══ ÇİFT İPTAL ═════════════════════════════════════════════════════════════════════════════
 * Kısmi unique indeks, aynı gideri iki kez geri almayı VERİTABANINDA kapatır. İstemci kapısı tek
 * başına yetmez: iki cihaz ÇEVRİMDIŞIYKEN aynı gideri iptal edebilir, birbirlerinin kapısını
 * göremezler ve iki ters satır parayı kasaya İKİ KEZ döndürüp append-only olarak kalıcı bozardı
 * (`cash_handovers` iptalinde 2026-08-13'te ödenmiş ders).
 *
 * İndeks YALNIZ 'expense' satırlarını kapsar: `correction` için aynı kuralı koymak, bu turda
 * incelenmemiş bir davranışı sessizce değiştirmek olurdu.
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
            "CHECK (entry_type IN ('debit','credit','payment','correction','discount','expense'))"
        );

        // KAPSAM KISITI: 'expense' de payment_type taşıyabilir. `discount` bilerek DIŞARIDA kalır
        // (kapıda kırılan tutar kasaya hiç girmez ve o teminatı bu yasak sağlıyor).
        DB::unprepared(
            'ALTER TABLE ledger_entries DROP CONSTRAINT IF EXISTS ledger_entries_payment_type_scope_check;'
        );
        DB::unprepared(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_payment_type_scope_check '.
            "CHECK (payment_type IS NULL OR entry_type IN ('payment', 'correction', 'expense')) NOT VALID;"
        );

        DB::unprepared(
            'CREATE UNIQUE INDEX IF NOT EXISTS ledger_entries_expense_reversal_uniq '.
            'ON ledger_entries (reverses_entry_id) '.
            "WHERE entry_type = 'expense' AND reverses_entry_id IS NOT NULL;"
        );
    }

    public function down(): void
    {
        DB::unprepared('DROP INDEX IF EXISTS ledger_entries_expense_reversal_uniq;');

        DB::unprepared(
            'ALTER TABLE ledger_entries DROP CONSTRAINT IF EXISTS ledger_entries_payment_type_scope_check;'
        );
        DB::unprepared(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_payment_type_scope_check '.
            "CHECK (payment_type IS NULL OR entry_type IN ('payment', 'correction')) NOT VALID;"
        );

        // Geri alırken 'expense' satırı KALMIŞSA CHECK eklenemez ve migration haklı olarak düşer:
        // kayıt silerek yol açmak append-only'yi (kırmızı çizgi #2) kırardı.
        DB::statement('ALTER TABLE ledger_entries DROP CONSTRAINT ledger_entries_type_check');
        DB::statement(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_type_check '.
            "CHECK (entry_type IN ('debit','credit','payment','correction','discount'))"
        );
    }
};
