<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * tenants.status → 'cancelled' eklenir (tasarım `03-BUGUN.jsx` DURUMLAR: deneme/aktif/askıda/İPTAL).
 *
 * NEDEN 'suspended' YETMEDİ: ikisi FARKLI olaylardır ve satış tarafında farklı davranırlar.
 *  - suspended (askıda) = BİZ kapattık; ödeyince aynı gün geri açılır, hâlâ müşterimizdir.
 *  - cancelled (iptal)  = BAYİ bıraktı; churn sayacına girer, hatırlatma/tahsilat listelerinde
 *    ARANMAZ. Tasarımın "Kuryesini işten çıkarmış, uygulamayı bıraktı" notu tam bu durumdur.
 * İkisini tek koda sıkıştırmak, churn oranını ölçmeyi imkânsız kılardı (BRIEF: erken terk sinyali
 * bu ürünün en pahalı metriğidir).
 *
 * VERİ SİLİNMEZ (BRIEF kırmızı çizgi #5 — "veri rehin alınmaz"): iptal YALNIZ yazmayı kapatır.
 * `TenantStatus::Cancelled->allowsLogin()` false döner ve `SyncService::resolveLock` bu durumu
 * locked/suspended ile AYNI kefeye koyar; bekleyen offline kayıtlar yine sunucuya akar, satırlar
 * yerinde durur, abonelik yenilenirse her şey geri gelir.
 *
 * CHECK kısıtı yeniden yazılır (Postgres'te CHECK'e değer eklemenin yolu drop+add'dir). Mevcut
 * satırlar etkilenmez: küme yalnız GENİŞLİYOR, hiçbir mevcut değer kısıt dışında kalmıyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
            ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_status_check;
            ALTER TABLE tenants ADD CONSTRAINT tenants_status_check
                CHECK (status IN ('trial','active','locked','suspended','cancelled'));
        SQL);
    }

    public function down(): void
    {
        // Geri alırken 'cancelled' satırlar kısıtı ihlal ederdi; ÖNCE onları 'suspended'a çekiyoruz.
        // Bilgi kaybı var ama geri alma zaten bilgi kaybıdır — sessiz bir migration hatasından iyidir.
        DB::unprepared(<<<'SQL'
            UPDATE tenants SET status = 'suspended' WHERE status = 'cancelled';
            ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_status_check;
            ALTER TABLE tenants ADD CONSTRAINT tenants_status_check
                CHECK (status IN ('trial','active','locked','suspended'));
        SQL);
    }
};
