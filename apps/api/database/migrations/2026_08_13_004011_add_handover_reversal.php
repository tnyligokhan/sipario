<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * ARA TAHSİLAT İPTALİ — cash_handovers.reverses_handover_id (kullanıcı kararı 2026-08-13).
 *
 * Yönetici yanlış girilmiş bir ara tahsilatı geri alabilmeli. GERÇEK SİLME YOK (kırmızı çizgi #2):
 * iptal, tablonun kendisine yazılan TERS BİR SATIRdır (`counted_cash_kurus` negatif, expected/diff
 * sıfır) ve iptal ettiği satırı bu kolonla işaret eder. `ledger_entries.reverses_entry_id` ile
 * BİREBİR aynı desen — para kayıtlarında düzeltme yalnız append ile yapılır, hata KANIT olarak
 * görünür kalır (BRIEF "eksik para kanıt olarak görünür kalmalı"). Kolon zaten migration 405 ile
 * UPDATE/DELETE'i REVOKE edilmiş bir tabloda yaşıyor; ezme yolu DB seviyesinde de kapalı.
 *
 * BİLEŞİK SELF-FK (tenant_id, reverses_handover_id) → (tenant_id, id): iptal yalnız AYNI bayinin
 * bir devrini gösterebilir (kırmızı çizgi #1). unique(tenant_id, id) Faz 4'ten beri var, referans
 * için ek indeks gerekmez. Uygulayıcı da (CashHandoverChangeApplier) RLS kapsamında ayrıca
 * doğrular — ikisi FARKLI şeyleri kapatır: uygulayıcı GÖRÜNÜR bir red üretir (`rejected`,
 * istemci karantinaya alır), FK ise koddaki bir gedik açıldığı gün son kapıdır.
 *
 * KISMİ UNIQUE İNDEKS (ÇİFT İPTALİ DB SEVİYESİNDE İMKÂNSIZ KILAR): bir devir EN FAZLA BİR KEZ
 * iptal edilebilir. Uygulayıcıdaki "zaten iptal edilmiş" kapısı tek başına YETMEZ; iki cihaz
 * çevrimdışıyken aynı tahsilatı iptal edip AYNI ANDA senkron olursa her iki isteğin okuması da
 * "henüz iptal yok" görür (okuma-sonra-yaz yarışı) ve para İKİ KEZ geri gelir — append-only
 * olduğu için de sonsuza kadar öyle kalır. Tekilliği veritabanına yazmak bu yarışı kapatan tek
 * yoldur; ikinci INSERT 23505 alır, o SQLSTATE `SyncService::CLIENT_DATA_SQLSTATES` beyaz
 * listesinde olduğu için parti düşmez, yalnız o olay 'rejected' olur.
 * `WHERE ... IS NOT NULL`: iptal OLMAYAN satırlar (yani devirlerin ezici çoğunluğu) kısıtın dışında
 * kalmalı — kısmi olmasaydı ikinci normal devir bile "null tekrarı" diye reddedilirdi.
 *
 * SENKRON SÖZLEŞMESİ (SyncPayload başlığındaki kontrol listesi):
 *  · Yalnız EKLEME → eski istemci bilmediği anahtarı yok sayar, MINOR (config/app.php 1.4.0).
 *  · Hiçbir mevcut satırın DEĞERİ değişmiyor → geriye dönük `sync_changes` yayını gerekmez
 *    (802 dersi burada tetiklenmiyor); ilk iptal normal push/pull yolundan iner.
 *  · Kolon senkron varlığına eklendiği için mobil ayrıştırıcı + mobil şema migration'ı da
 *    güncellenir (bu vardiyada 'mobil' ajanı yapıyor). Eksik kalan yer SESSİZDİR.
 *
 * RLS: cash_handovers 000404'ten beri ENABLE+FORCE RLS; policy ve GRANT tablo düzeyindedir, yeni
 * sütun otomatik kapsanır (kolon düzeyinde yetki kullanılmıyor).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('cash_handovers', function (Blueprint $table) {
            $table->uuid('reverses_handover_id')->nullable()->after('to_user_id');
        });

        DB::statement(
            'ALTER TABLE cash_handovers ADD CONSTRAINT cash_handovers_reverses_fk '.
            'FOREIGN KEY (tenant_id, reverses_handover_id) '.
            'REFERENCES cash_handovers (tenant_id, id)'
        );

        DB::statement(
            'CREATE UNIQUE INDEX cash_handovers_reverses_unique '.
            'ON cash_handovers (tenant_id, reverses_handover_id) '.
            'WHERE reverses_handover_id IS NOT NULL'
        );
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS cash_handovers_reverses_unique');
        DB::statement('ALTER TABLE cash_handovers DROP CONSTRAINT cash_handovers_reverses_fk');

        Schema::table('cash_handovers', fn (Blueprint $t) => $t->dropColumn('reverses_handover_id'));
    }
};
