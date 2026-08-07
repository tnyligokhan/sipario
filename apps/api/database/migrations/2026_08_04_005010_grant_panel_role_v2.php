<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * YENİ ABONELİK/PANEL TABLOLARININ YETKİ MATRİSİ (000504'ün devamı).
 *
 * İKİ KURAL:
 *
 * 1) `sipario_app` (RLS altındaki UYGULAMA rolü) bu tabloların HİÇBİRİNİ GÖREMEZ.
 *    - `plans`, `expenses`, `addon_packages` ŞİRKET verisidir (fiyat politikamız, giderlerimiz).
 *    - `addon_grants`, `tenant_notes`, `payment_notifications` bayiye gösterilmez (kime bedelsiz
 *      paket verdiğimiz, hakkında ne not tuttuğumuz, beyanının hangi aşamada olduğu).
 *    Postgres yeni tabloya kendiliğinden izin vermez (ALTER DEFAULT PRIVILEGES kurulmadı), yani
 *    burada aslında "hiçbir şey yapmamak" yeterliydi. Yine de AÇIK REVOKE yazılıyor: bir gün biri
 *    default privileges tanımlarsa ya da elle GRANT ederse, bu migration'ın niyeti dosyada durur ve
 *    izin testi (PanelPermissionTest deseni) neyi kanıtlaması gerektiğini bilir.
 *
 * 2) `sipario_panel` bu tabloların TAMAMINDA yalnız SELECT alır — YAZAMAZ.
 *    NEDEN: App\Abonelik altındaki her yazma ya ÇOK TABLOLU tek bir transaction'dır (ödeme satırı +
 *    tenants.valid_until + kota kolonu) ya da PUBLIC SİTEDEN de koşmak zorundadır (bayinin havale
 *    bildirimi — orada panel rolü yoktur). İkisi de `pgsql_owner` gerektirir. Panel rolüne ayrıca
 *    yazma izni vermek, hiçbir kodun kullanmadığı ama bir hata anında para kaydını değiştirebilecek
 *    bir kapı açmak olurdu; 000504'ün felsefesi bunun tersidir (izin, kodun İHTİYACI kadar).
 *
 * `subscription_payments` DE BURADA: panelin bu tabloda bugüne kadar HİÇBİR izni yoktu (000504
 * listesinde yok) — yani "Ödemeler" ekranı ve gelir raporu panel bağlantısıyla ÇALIŞAMAZDI. SELECT
 * veriliyor; INSERT bilinçli olarak VERİLMİYOR (elle ödeme kaydı owner ile, tek transaction).
 *
 * `sipario_owner` için GRANT YAZILMAZ: tabloların sahibidir (ve imajda superuser) — sahibin
 * kendi tablosuna izne ihtiyacı yoktur, yazmak yanıltıcı olurdu.
 */
return new class extends Migration
{
    /** Bu vardiyada açılan tablolar — panel OKUR, uygulama GÖRMEZ. */
    private const YENI_TABLOLAR = [
        'plans', 'addon_packages', 'addon_grants', 'expenses', 'tenant_notes', 'payment_notifications',
    ];

    public function up(): void
    {
        $tablolar = implode(', ', self::YENI_TABLOLAR);

        DB::unprepared(<<<SQL
            GRANT SELECT ON {$tablolar} TO sipario_panel;

            -- Ödemeler ekranı + aylık gelir raporu. Yazma YOK (append-only tarafa yalnız owner yazar).
            GRANT SELECT ON subscription_payments TO sipario_panel;

            -- Uygulama rolü bu tabloları GÖRMEZ (niyet beyanı; bkz. sınıf yorumu).
            REVOKE ALL ON {$tablolar} FROM sipario_app;
        SQL);
    }

    public function down(): void
    {
        $tablolar = implode(', ', self::YENI_TABLOLAR);

        DB::unprepared(<<<SQL
            REVOKE SELECT ON {$tablolar} FROM sipario_panel;
            REVOKE SELECT ON subscription_payments FROM sipario_panel;
        SQL);
    }
};
