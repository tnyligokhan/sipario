<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Faz 2 tablolarında kiracı izolasyonu (kırmızı çizgi #1). Faz 1 (2026_07_11_130000) desenini
 * birebir tekrarlar: her tabloda ENABLE + FORCE ROW LEVEL SECURITY + tenant policy'si.
 *
 *  - Güvenli varsayılan: app.tenant_id set edilmemişse (NULLIF ... = NULL) hiçbir satır görünmez.
 *  - FORCE: owner ile yanlışlıkla bağlanılsa bile izolasyon korunur (kuşak + askı).
 *  - Bu migration owner (sipario_owner) ile koşar. DML yetkileri Faz 1'in ALTER DEFAULT PRIVILEGES'ı
 *    sayesinde bu yeni tablolara otomatik gelir; yine de emniyet için açık GRANT ekleniyor.
 *
 * tenant_sync_state'in ayrımlayıcı kolonu tenant_id'dir (PK aynı zamanda); policy ona göre.
 */
return new class extends Migration
{
    /** RLS uygulanacak tablolar; hepsinde tenant_id kolonu var. */
    private const TABLES = [
        'customers',
        'customer_phones',
        'customer_addresses',
        'products',
        'orders',
        'order_lines',
        'order_events',
        'ledger_entries',
        'tenant_sync_state',
        'sync_changes',
        'processed_events',
    ];

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

        // Emniyet: yeni tablolara ve bigserial sequence'lerine app rolü DML yetkisi (default privilege'e ek).
        DB::unprepared(<<<'SQL'
            GRANT SELECT, INSERT, UPDATE, DELETE ON
                customers, customer_phones, customer_addresses, products,
                orders, order_lines, order_events, ledger_entries,
                tenant_sync_state, sync_changes, processed_events
            TO sipario_app;
            GRANT USAGE, SELECT ON
                sync_changes_id_seq, processed_events_id_seq
            TO sipario_app;
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
