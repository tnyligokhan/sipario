<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Tasarım boşluğu tablolarında kiracı izolasyonu (kırmızı çizgi #1). Faz 1/2/3/4 desenini birebir
 * tekrarlar: ENABLE + FORCE ROW LEVEL SECURITY + güvenli-varsayılan politika (app.tenant_id set
 * edilmemişse HİÇBİR satır görünmez) + açık GRANT.
 *
 * tenant_settings'te politika `tenant_id` sütunu üzerinden çalışır (bu tabloda tenant_id aynı zamanda
 * birincil anahtardır) — diğer tablolarla aynı ifade, ek bir kural yok.
 */
return new class extends Migration
{
    private const TABLES = ['tenant_settings', 'exempt_numbers', 'call_logs', 'day_closings'];

    public function up(): void
    {
        foreach (self::TABLES as $table) {
            DB::unprepared(<<<SQL
                ALTER TABLE {$table} ENABLE ROW LEVEL SECURITY;
                ALTER TABLE {$table} FORCE ROW LEVEL SECURITY;
                CREATE POLICY tenant_isolation ON {$table}
                    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                    WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

                GRANT SELECT, INSERT, UPDATE, DELETE ON {$table} TO sipario_app;
                GRANT SELECT ON {$table} TO sipario_panel;
            SQL);
        }
    }

    public function down(): void
    {
        foreach (self::TABLES as $table) {
            DB::unprepared(<<<SQL
                DROP POLICY IF EXISTS tenant_isolation ON {$table};
                ALTER TABLE {$table} NO FORCE ROW LEVEL SECURITY;
                ALTER TABLE {$table} DISABLE ROW LEVEL SECURITY;
            SQL);
        }
    }
};
