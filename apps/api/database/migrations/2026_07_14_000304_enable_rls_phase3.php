<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * FAZ 3 kupon tablolarında kiracı izolasyonu (kırmızı çizgi #1). Faz 1/2 desenini birebir tekrarlar:
 * her tabloda ENABLE + FORCE ROW LEVEL SECURITY + tenant policy'si (güvenli varsayılan: app.tenant_id
 * set edilmemişse hiçbir satır görünmez). coupon_balances'ın ayrımlayıcı kolonu da tenant_id.
 */
return new class extends Migration
{
    private const TABLES = ['coupon_movements', 'coupon_balances'];

    public function up(): void
    {
        foreach (self::TABLES as $table) {
            DB::unprepared(<<<SQL
                ALTER TABLE {$table} ENABLE ROW LEVEL SECURITY;
                ALTER TABLE {$table} FORCE ROW LEVEL SECURITY;
                CREATE POLICY tenant_isolation ON {$table}
                    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                    WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
            SQL);
        }

        DB::unprepared(<<<'SQL'
            GRANT SELECT, INSERT, UPDATE, DELETE ON coupon_movements, coupon_balances TO sipario_app;
        SQL);
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
