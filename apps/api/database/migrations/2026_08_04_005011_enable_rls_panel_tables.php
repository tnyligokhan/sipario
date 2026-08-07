<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * KİRACI-KAPSAMLI YENİ TABLOLARDA RLS (kırmızı çizgi #1 — kuşak + kemer).
 *
 * `addon_grants`, `tenant_notes`, `payment_notifications` bir bayiye aittir. Bugün sipario_app'in
 * bu tablolarda HİÇBİR izni yok (005010), yani izolasyon zaten "erişim yok" ile sağlanıyor. Buna
 * rağmen politika kuruluyor, çünkü bu deponun en pahalı hatası tam bu boşluktan çıkar: yarın biri
 * bayinin hesap sayfasında "ödeme bildirimlerim" listesini gösterebilmek için tek satırlık bir
 * GRANT yazar ve o an — politika yoksa — bayi HERKESİN bildirimini görür. Politika önce kurulursa
 * o GRANT güvenlidir.
 *
 * `plans`, `addon_packages`, `expenses` KAPSAM DIŞI: kiracıya ait değiller (şirket verisi), izole
 * edilecek bir tenant_id'leri yok. Onların koruması yalnızca izin matrisidir.
 *
 * FORCE RLS tablo sahibini de bağlar; `sipario_owner` imajda superuser olduğu için yazımları
 * (site bildirimi, panel tanımlaması) etkilenmez — subscription_payments 000506'da aynı desen
 * zaten üretimde çalışıyor. `sipario_panel` BYPASSRLS ile cross-tenant okumaya devam eder.
 */
return new class extends Migration
{
    private const TABLOLAR = ['addon_grants', 'tenant_notes', 'payment_notifications'];

    public function up(): void
    {
        foreach (self::TABLOLAR as $tablo) {
            DB::unprepared(<<<SQL
                ALTER TABLE {$tablo} ENABLE ROW LEVEL SECURITY;
                ALTER TABLE {$tablo} FORCE ROW LEVEL SECURITY;
                CREATE POLICY tenant_isolation ON {$tablo}
                    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                    WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
            SQL);
        }
    }

    public function down(): void
    {
        foreach (self::TABLOLAR as $tablo) {
            DB::unprepared(<<<SQL
                DROP POLICY IF EXISTS tenant_isolation ON {$tablo};
                ALTER TABLE {$tablo} NO FORCE ROW LEVEL SECURITY;
                ALTER TABLE {$tablo} DISABLE ROW LEVEL SECURITY;
            SQL);
        }
    }
};
