<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * 13.11.2026 YEDEK DÖNÜŞÜ ONARIMI (2026-11-17).
 *
 * Sunucu sıfırdan ayağa kaldırılıp 13.11.2026 tarihli `pg_dump` yedeği yüklendiğinde iki yapısal
 * sorun doğdu:
 *
 *  1. İZİN VE FONKSİYON SAHİPLİĞİ KAYBI: `docker/backup/backup.sh` yedeği `--no-owner
 *     --no-privileges --clean --if-exists` ile alıyordu. Yedek yüklendiğinde tablolar ve
 *     `sipario_login_lookup` fonksiyonları düşürülüp `sipario_owner` sahipliğinde yeniden
 *     yaratıldı; ancak `migrations` tablosu yedekte zaten dolu geldiği için `004006`, `000504`,
 *     `005010` gibi rol/GRANT migration'ları yeniden KOŞMADI. Bu migration tüm runtime (`sipario_app`),
 *     kimlik doğrulama (`sipario_auth`) ve panel (`sipario_panel`) izinlerini idempotent olarak
 *     yeniden kurar.
 *
 *  2. SENKRON İMLECİ (`last_seq`) GERİYE DÜŞMESİ: Telefonların `sync_meta.lastPulledSeq` değeri
 *     17 Kasım'daki ileri sayıda kalırken, sunucudaki `tenant_sync_state.last_seq` 13 Kasım
 *     yedeğindeki küçük sayıya düştü. Telefon `pull?since=<17_kasim_seq>` istediğinde sunucu
 *     daha küçük `seq` ürettiği için yeni deltalar telefona ulaşmıyordu. Mevcut kiracıların
 *     (`last_seq > 0` ve `< 100000`) sayaçları ve yedek sonrası yazılmış `sync_changes` /
 *     `processed_events` sıra numaraları +100.000 ileri taşınarak tüm cihaz imleçlerinin önüne
 *     geçirilir.
 */
return new class extends Migration
{
    public const SEQ_KAYDIRMA = 100_000;

    public const YEDEK_KESIMI = '2026-11-13 12:00:00+00';

    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        $this->rolleriVeIzinleriOnar();
        $this->senkronSayaclariniIleriTasi();
    }

    public function down(): void
    {
        // Onarım migration'ı geri alınmaz (izinler ve monoton seq korunur).
    }

    private function rolleriVeIzinleriOnar(): void
    {
        $appPass = str_replace("'", "''", (string) config('database.connections.pgsql.password'));
        $panelPass = str_replace("'", "''", (string) config('database.connections.pgsql_panel.password'));
        $dbName = config('database.connections.pgsql.database', 'sipario');

        DB::unprepared(<<<SQL
            DO \$\$ BEGIN
                IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_app') THEN
                    CREATE ROLE sipario_app LOGIN PASSWORD '{$appPass}'
                        NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
                ELSE
                    ALTER ROLE sipario_app WITH PASSWORD '{$appPass}';
                END IF;

                IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_auth') THEN
                    CREATE ROLE sipario_auth NOLOGIN NOSUPERUSER BYPASSRLS;
                END IF;

                IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_panel') THEN
                    CREATE ROLE sipario_panel LOGIN PASSWORD '{$panelPass}'
                        NOSUPERUSER NOCREATEDB NOCREATEROLE BYPASSRLS;
                ELSE
                    ALTER ROLE sipario_panel WITH PASSWORD '{$panelPass}';
                END IF;
            END \$\$;

            GRANT CONNECT ON DATABASE "{$dbName}" TO sipario_app;
            GRANT USAGE ON SCHEMA public TO sipario_app;
            GRANT CONNECT ON DATABASE "{$dbName}" TO sipario_panel;
            GRANT USAGE ON SCHEMA public TO sipario_panel;

            -- Login lookup fonksiyonlarının BYPASSRLS sahibi (sipario_auth) ve çalışma izinleri
            ALTER FUNCTION sipario_login_lookup(text) OWNER TO sipario_auth;
            REVOKE ALL ON FUNCTION sipario_login_lookup(text) FROM PUBLIC;
            GRANT EXECUTE ON FUNCTION sipario_login_lookup(text) TO sipario_app;

            ALTER FUNCTION sipario_login_lookup(text, text) OWNER TO sipario_auth;
            REVOKE ALL ON FUNCTION sipario_login_lookup(text, text) FROM PUBLIC;
            GRANT EXECUTE ON FUNCTION sipario_login_lookup(text, text) TO sipario_app;

            GRANT SELECT ON users, tenants TO sipario_auth;

            -- Runtime uygulama rolü (sipario_app) DML yetkileri + append-only/panel kısıtları
            GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sipario_app;
            GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sipario_app;

            ALTER DEFAULT PRIVILEGES FOR ROLE sipario_owner IN SCHEMA public
                GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sipario_app;
            ALTER DEFAULT PRIVILEGES FOR ROLE sipario_owner IN SCHEMA public
                GRANT USAGE, SELECT ON SEQUENCES TO sipario_app;

            REVOKE UPDATE, DELETE ON
                ledger_entries, order_events, sync_changes, processed_events,
                cash_handovers, subscription_payments, day_closings
            FROM sipario_app;

            REVOKE ALL ON
                admin_users, panel_audit, plans, addon_packages, addon_grants,
                expenses, tenant_notes, payment_notifications
            FROM sipario_app;

            -- Yönetim paneli rolü (sipario_panel) yetki matrisi
            GRANT SELECT ON
                customers, customer_phones, customer_addresses, products,
                orders, order_lines, order_events, ledger_entries,
                cash_handovers, devices, users,
                tenant_settings, exempt_numbers, call_logs, day_closings,
                plans, addon_packages, addon_grants, expenses,
                tenant_notes, payment_notifications, subscription_payments
            TO sipario_panel;

            GRANT SELECT, UPDATE ON tenants TO sipario_panel;
            GRANT SELECT, INSERT, UPDATE ON admin_users TO sipario_panel;
            GRANT SELECT, INSERT ON panel_audit TO sipario_panel;
        SQL);
    }

    private function senkronSayaclariniIleriTasi(): void
    {
        $kaydirma = self::SEQ_KAYDIRMA;
        $kesim = self::YEDEK_KESIMI;

        // Yedek yüklendikten sonra yazılmış değişikliklerin seq numaralarını da aynı ofsetle
        // ileri taşı ki telefonların eski lastPulledSeq değerinin üstüne çıksınlar.
        DB::statement(
            'UPDATE sync_changes SET seq = seq + ?
             WHERE tenant_id IN (SELECT tenant_id FROM tenant_sync_state WHERE last_seq > 0 AND last_seq < ?)
               AND created_at >= ?
               AND seq < ?',
            [$kaydirma, $kaydirma, $kesim, $kaydirma]
        );

        DB::statement(
            'UPDATE processed_events SET result_seq = result_seq + ?
             WHERE tenant_id IN (SELECT tenant_id FROM tenant_sync_state WHERE last_seq > 0 AND last_seq < ?)
               AND created_at >= ?
               AND result_seq IS NOT NULL
               AND result_seq < ?',
            [$kaydirma, $kaydirma, $kesim, $kaydirma]
        );

        DB::statement(
            'UPDATE tenant_sync_state SET last_seq = last_seq + ?, updated_at = now()
             WHERE last_seq > 0 AND last_seq < ?',
            [$kaydirma, $kaydirma]
        );
    }
};
