<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * call_logs.user_id — çağrıyı KİM karşıladı / kim yaptı (kullanıcı isteği 2026-08-13).
 *
 * NEDEN `device_id` YETMEDİ: tablo Faz 4'ten beri `device_id` taşıyor ama o bir CİHAZI anlatır,
 * kişiyi değil. Aynı telefonu iki kişi kullanabilir (patron sabah, operatör akşam) ve bir kurye
 * telefonunu değiştirdiğinde geçmişi kopar. Patronun sorduğu soru "hangi telefondan arandı"
 * değil, "kim aradı".
 *
 * NULLABLE ve GERİYE DÖNÜK DOLDURULMAZ: bu kolondan önce yazılmış satırların atfı BİLİNMİYOR.
 * `device_id`den kişiye eşleme yapmak "o gün o cihazı kim kullanıyordu" VARSAYIMIDIR; yanlış bir
 * isim, bir kuryeyi yapmadığı bir aramadan sorumlu tutar. Boş bırakmak dürüsttür ve istemci
 * ekranı bunu "bilinmiyor" diye yazar.
 *
 * ÇAPRAZ BAYİ KORUMASI VERİTABANINDA (kırmızı çizgi #1): bileşik FK
 * `(tenant_id, user_id) → users (tenant_id, id)`. `users` tablosunda `unique(tenant_id, id)`
 * 000002'den beri var. Uygulayıcıya AYRICA açık bir kontrol EKLENMEDİ ve bu bilinçli: call_log
 * `ChangeApplier::SIMPLE_ENTITIES` üzerinden genel LWW yolundan geçiyor, oraya varlığa özel bir
 * dal açmak o yolun sadeliğini bozardı. FK ihlali 23503 verir; o SQLSTATE
 * `SyncService::CLIENT_DATA_SQLSTATES` beyaz listesinde olduğu için parti düşmez, yalnız o olay
 * 'rejected' olur. Bedeli kabul edildi: istemciye giden mesaj `CashHandoverChangeApplier`ınki
 * kadar açıklayıcı değil (gerekçe yerine ham kısıt hatası).
 *
 * SENKRON SÖZLEŞMESİ (SyncPayload kontrol listesi):
 *  · Yalnız EKLEME → eski istemci bilmediği anahtarı yok sayar, MINOR sürüm artışı.
 *  · Hiçbir mevcut satırın DEĞERİ değişmiyor → geriye dönük `sync_changes` yayını gerekmez.
 *  · Kolon senkron varlığına eklendiği için mobil şema (drift v21), ayrıştırıcı ve outbox yükü
 *    de bu vardiyada güncellendi. Eksik kalan yer SESSİZDİR.
 *
 * RLS: call_logs 000603'ten beri ENABLE+FORCE RLS; policy ve GRANT tablo düzeyindedir, yeni
 * sütun otomatik kapsanır (kolon düzeyinde yetki kullanılmıyor).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('call_logs', function (Blueprint $table) {
            $table->uuid('user_id')->nullable()->after('related_order_id');
        });

        DB::statement(
            'ALTER TABLE call_logs ADD CONSTRAINT call_logs_user_fk '.
            'FOREIGN KEY (tenant_id, user_id) REFERENCES users (tenant_id, id)'
        );

        // Patronun asıl sorgusu "şu kullanıcının çağrıları, yeniden eskiye" — indeks o sorgunun
        // şeklinde. Çağrı günlüğü zamanla en hızlı büyüyen tablolardan biridir (her zil bir
        // satır) ve kullanıcıya göre süzme onsuz tam tarama olurdu.
        DB::statement(
            'CREATE INDEX call_logs_tenant_user_time_idx '.
            'ON call_logs (tenant_id, user_id, occurred_at DESC)'
        );
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS call_logs_tenant_user_time_idx');
        DB::statement('ALTER TABLE call_logs DROP CONSTRAINT IF EXISTS call_logs_user_fk');

        Schema::table('call_logs', function (Blueprint $table) {
            $table->dropColumn('user_id');
        });
    }
};
