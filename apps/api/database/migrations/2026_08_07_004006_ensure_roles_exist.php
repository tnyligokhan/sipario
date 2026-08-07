<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * ÜRETİM VE CANLI ORTAMLAR İÇİN ROL GÜVENCESİ.
 *
 * `pgsql_owner` (migration sahibi) bağlantısıyla koşar.
 * Veritabanında `sipario_app` ve `sipario_panel` rollerinin VARLIĞINI ve ŞİFRELERİNİ
 * env değişkenleriyle eşler, erişim izinlerini verir.
 *
 * Böylece Postgres init betiğinin kaçırıldığı veya kalıcı volume durumlarında bile
 * migrate komutu çalıştığı anda uygulama ve panel rollerini garanti eder.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Yalnız PostgreSQL bağlantısında çalışır
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        $appPass = config('database.connections.pgsql.password');
        $panelPass = config('database.connections.pgsql_panel.password');
        $dbName = config('database.connections.pgsql.database', 'sipario');

        // Şifrelerdeki tırnak işaretlerini kaçır
        $appPassEscaped = str_replace("'", "''", (string) $appPass);
        $panelPassEscaped = str_replace("'", "''", (string) $panelPass);

        DB::unprepared(<<<SQL
            DO \$\$ BEGIN
                IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_app') THEN
                    CREATE ROLE sipario_app LOGIN PASSWORD '{$appPassEscaped}'
                        NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
                ELSE
                    ALTER ROLE sipario_app WITH PASSWORD '{$appPassEscaped}';
                END IF;

                IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_auth') THEN
                    CREATE ROLE sipario_auth NOLOGIN NOSUPERUSER BYPASSRLS;
                END IF;

                IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_panel') THEN
                    CREATE ROLE sipario_panel LOGIN PASSWORD '{$panelPassEscaped}'
                        NOSUPERUSER NOCREATEDB NOCREATEROLE BYPASSRLS;
                ELSE
                    ALTER ROLE sipario_panel WITH PASSWORD '{$panelPassEscaped}';
                END IF;
            END \$\$;

            GRANT CONNECT ON DATABASE "{$dbName}" TO sipario_app;
            GRANT USAGE ON SCHEMA public TO sipario_app;
            GRANT CONNECT ON DATABASE "{$dbName}" TO sipario_panel;
            GRANT USAGE ON SCHEMA public TO sipario_panel;

            -- Tüm mevcut ve gelecekteki tablolara sipario_app DML yetkileri
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
        // Rolleri down'da silmiyoruz (bağımlı veriler ve RLS kuralları olabilir)
    }
};
