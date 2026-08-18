<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * KAPANIŞI GERİ ALMA — day_closings.reverses_closing_id (kullanıcı kararı 2026-08-18:
 * "patron hata yapabilir, kasayı kapattığında yönetici şifresi ile geriye alabilir").
 *
 * Bugüne kadar kapanış TEK YÖNLÜYDÜ: yanlış sayılmış bir nakit, arşive KALICI donuyordu ve gün
 * kilitli kaldığı için hiçbir düzeltme yolu yoktu. Patronun elinde kalan tek çare ertesi gün
 * defterde ters kayıt yazmaktı — yani hatanın izi doğru yerde değil, bir gün ilerideydi.
 *
 * GERÇEK SİLME YOK (kırmızı çizgi #2): geri alma, tablonun kendisine yazılan TERS BİR SATIRdır ve
 * geri aldığı kapanışı bu kolonla işaret eder. `cash_handovers.reverses_handover_id` (migration
 * 004011) ve `ledger_entries.reverses_entry_id` ile BİREBİR aynı desen — hata KANIT olarak görünür
 * kalır, düzeltme yalnız append ile yapılır. Tablonun UPDATE/DELETE yetkisi migration 607'de zaten
 * geri alınmıştı; ezme yolu DB seviyesinde de kapalı.
 *
 * BİLEŞİK SELF-FK (tenant_id, reverses_closing_id) → (tenant_id, id): geri alma yalnız AYNI
 * bayinin bir kapanışını gösterebilir (kırmızı çizgi #1).
 *
 * KISMİ UNIQUE İNDEKS — ÇİFT GERİ ALMAYI DB SEVİYESİNDE İMKÂNSIZ KILAR. Uygulayıcıdaki "zaten
 * geri alınmış" kapısı tek başına YETMEZ: iki cihaz çevrimdışıyken aynı kapanışı geri alıp AYNI
 * ANDA senkron olursa iki okuma da "henüz geri alma yok" görür (okuma-sonra-yaz yarışı) ve gün
 * iki kez açılmış sayılır. Append-only olduğu için de sonsuza kadar öyle kalırdı.
 *
 * ⚠️ CHECK KISITI GENİŞLETİLİYOR (`day_closings_scope_user_check`): geri alma satırı, geri aldığı
 * kapanışın scope/user'ını AYNEN taşır, yani mevcut kural onu zaten kabul eder. Kısıt burada
 * DEĞİŞTİRİLMİYOR — bu not, "genişletmek gerekir mi?" sorusunu bir daha soranın cevabı için var:
 * gerekmiyor, çünkü ters satır bir istisna değil aynı ailenin bir üyesidir.
 *
 * SENKRON SÖZLEŞMESİ (SyncPayload kontrol listesi):
 *  · Yalnız EKLEME → eski istemci bilmediği anahtarı yok sayar; MINOR.
 *  · ⚠️ AMA ESKİ İSTEMCİ İÇİN ANLAM DEĞİŞİR ve bu bilinçli bir bedeldir: 0.28.0 ve öncesi bir
 *    telefon, geri alma satırını "ikinci bir kapanış" olarak indirir ve o günü hâlâ KAPALI görür.
 *    Yani eski telefonda gün yeniden açılmaz. Yanlış para GÖSTERMEZ (arşiv satırları olduğu gibi
 *    durur), yalnız yeni yeteneği kullanamaz — güncelleme inince kendiliğinden düzelir. Alternatif
 *    (yeni bir entity_type) eski istemcide olayın TAMAMEN kaybolması demekti; görünür ama etkisiz
 *    olmak, hiç olmamaktan iyidir.
 *  · Hiçbir mevcut satırın DEĞERİ değişmiyor → geriye dönük `sync_changes` yayını gerekmez.
 *
 * RLS: day_closings 000606'dan beri ENABLE+FORCE RLS; policy ve GRANT tablo düzeyindedir, yeni
 * sütun otomatik kapsanır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('day_closings', function (Blueprint $table) {
            $table->uuid('reverses_closing_id')->nullable()->after('user_id');
        });

        DB::statement(
            'ALTER TABLE day_closings ADD CONSTRAINT day_closings_reverses_fk '.
            'FOREIGN KEY (tenant_id, reverses_closing_id) '.
            'REFERENCES day_closings (tenant_id, id)'
        );

        DB::statement(
            'CREATE UNIQUE INDEX day_closings_reverses_unique '.
            'ON day_closings (tenant_id, reverses_closing_id) '.
            'WHERE reverses_closing_id IS NOT NULL'
        );
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS day_closings_reverses_unique');
        DB::statement('ALTER TABLE day_closings DROP CONSTRAINT day_closings_reverses_fk');

        Schema::table('day_closings', fn (Blueprint $t) => $t->dropColumn('reverses_closing_id'));
    }
};
