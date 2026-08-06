<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * `payment_type` YALNIZ `payment`/`correction` KAYDINDA — kural artık VERİTABANINDA da duruyor.
 *
 * NEDEN: kural bugüne kadar TEK bir yerde, `ChangeApplier::validateLedgerEntry`de yaşıyordu, yani
 * yalnız SENKRON yolunda. Eloquent'le doğrudan yazan her yol (seeder, komut, gelecekteki bir
 * servis) kapının yanından geçiyordu ve `DemoSeeder` fiilen geçiyordu da: fazla ödemeyi `credit` +
 * `payment_type: havale` olarak yazıyordu (2026-08-06'da `payment`e çevrildi). İki katman neyin
 * meşru olduğunda ayrışınca ortada hakem kalmıyor — bu migration hakemi koyuyor.
 *
 * KURALIN TAŞIDIĞI İKİ İNVARİANT:
 *  1. "payment_type taşıyan kayıt = kasaya dokundu" (DECISIONS Faz 3). Gün sonu kasa özeti tam
 *     olarak bu süzgeçle çalışır (`payment_type IS NOT NULL`); kuralın gevşemesi kasaya girmemiş
 *     parayı kasa sayımına sokar ve gün sonu farkını KANIT olmaktan çıkarıp gürültüye çevirir.
 *  2. İSKONTO TEMİNATI (2026-07-30): `discount` kapıda kırılan tutardır, borcu `payment` gibi
 *     düşürür ama kasaya HİÇ girmez. Kasaya sızmamasını sağlayan tek şey `payment_type` yasağıdır.
 *     Yasağı gevşetmek iskonto teminatını da gevşetir — bu yüzden `discount` bilerek dışarıda.
 *
 * NEDEN `NOT VALID`: kısıt YENİ ve GÜNCELLENEN satırlara uygulanır, MEVCUT satırlar taranmaz.
 * Bu makinede gerçek saha verisi var ve `ledger_entries` APPEND-ONLY'dir (migration 211
 * `sipario_app`ten UPDATE/DELETE'i geri alır) — yani kurala uymayan eski bir satır bulunsa onu
 * DÜZELTMENİN yolu yok, tek çıkış `migrate:fresh` olurdu ve para kaydı yeniden yazılamaz
 * (kırmızı çizgi #2/#3). Geçmişi yargılamadan geleceği kapatıyoruz.
 *
 * TAMAMLANABİLİR: mevcut satırların temiz olduğu doğrulandığında kısıt
 * `ALTER TABLE ledger_entries VALIDATE CONSTRAINT ledger_entries_payment_type_scope_check;`
 * ile tam kısıta yükseltilebilir. VALIDATE yalnız SHARE UPDATE EXCLUSIVE alır (yazmayı bloklamaz),
 * yani ayrı bir bakım penceresi gerektirmez. Önce şu sorgu BOŞ dönmeli:
 *   SELECT id, entry_type, payment_type FROM ledger_entries
 *    WHERE payment_type IS NOT NULL AND entry_type NOT IN ('payment','correction');
 *
 * Mevcut `ledger_entries_payment_type_check` DEĞERİ kısıtlar (nakit|kart|havale); bu kısıt
 * KAPSAMI kısıtlar (hangi entry_type taşıyabilir). İkisi ayrı sorular, ayrı kısıtlar.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_payment_type_scope_check '.
            "CHECK (payment_type IS NULL OR entry_type IN ('payment', 'correction')) NOT VALID;"
        );
    }

    public function down(): void
    {
        DB::unprepared(
            'ALTER TABLE ledger_entries DROP CONSTRAINT IF EXISTS ledger_entries_payment_type_scope_check;'
        );
    }
};
