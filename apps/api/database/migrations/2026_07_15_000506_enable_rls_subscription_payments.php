<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * FAZ 5b — subscription_payments kiracı izolasyonu (kırmızı çizgi #1) + APPEND-ONLY (kırmızı çizgi #2).
 * Faz 1/2/3/4 desenini birebir izler: ENABLE + FORCE RLS + güvenli-varsayılan tenant policy'si;
 * sipario_app'ten UPDATE/DELETE REVOKE (ledger_entries 211 / cash_handovers 405 simetriği).
 *
 * Yazımlar aktivasyon callback'inde owner ile yapılır (privileged; abonelik durumu tek doğru kaynak
 * sunucu); REVOKE bir kod hatasının bile ödeme geçmişini ezmesini/silmesini DB seviyesinde engeller.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
            ALTER TABLE subscription_payments ENABLE ROW LEVEL SECURITY;
            ALTER TABLE subscription_payments FORCE ROW LEVEL SECURITY;
            CREATE POLICY tenant_isolation ON subscription_payments
                USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

            GRANT SELECT, INSERT ON subscription_payments TO sipario_app;
            REVOKE UPDATE, DELETE ON subscription_payments FROM sipario_app;
        SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
            DROP POLICY IF EXISTS tenant_isolation ON subscription_payments;
            ALTER TABLE subscription_payments NO FORCE ROW LEVEL SECURITY;
            ALTER TABLE subscription_payments DISABLE ROW LEVEL SECURITY;
        SQL);
    }
};
