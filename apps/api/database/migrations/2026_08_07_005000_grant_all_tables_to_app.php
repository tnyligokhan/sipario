<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Mevcut tüm veritabanı tabloları ve dizileri (sequences) üzerinde
 * sipario_app ve sipario_panel izinlerini tazeleyen ve eksikleri gideren migration.
 */
return new class extends Migration {
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        DB::unprepared(<<<'SQL'
            GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sipario_app;
            GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sipario_app;

            ALTER DEFAULT PRIVILEGES FOR ROLE sipario_owner IN SCHEMA public
                GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sipario_app;
            ALTER DEFAULT PRIVILEGES FOR ROLE sipario_owner IN SCHEMA public
                GRANT USAGE, SELECT ON SEQUENCES TO sipario_app;
        SQL);
    }

    public function down(): void
    {
    }
};
