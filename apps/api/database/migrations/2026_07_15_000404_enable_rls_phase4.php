<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * FAZ 4 cash_handovers tablosunda kiracı izolasyonu (kırmızı çizgi #1). Faz 1/2/3 desenini birebir
 * tekrarlar: ENABLE + FORCE ROW LEVEL SECURITY + tenant policy'si (güvenli varsayılan: app.tenant_id
 * set edilmemişse hiçbir satır görünmez). Emniyet için açık GRANT (default privilege'e ek).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
            ALTER TABLE cash_handovers ENABLE ROW LEVEL SECURITY;
            ALTER TABLE cash_handovers FORCE ROW LEVEL SECURITY;
            CREATE POLICY tenant_isolation ON cash_handovers
                USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

            GRANT SELECT, INSERT, UPDATE, DELETE ON cash_handovers TO sipario_app;
        SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
            DROP POLICY IF EXISTS tenant_isolation ON cash_handovers;
            ALTER TABLE cash_handovers NO FORCE ROW LEVEL SECURITY;
            ALTER TABLE cash_handovers DISABLE ROW LEVEL SECURITY;
        SQL);
    }
};
