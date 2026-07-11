<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Kiracı izolasyonunun kalbi (kırmızı çizgi #1). Bu migration owner (sipario_owner) ile koşar.
 *
 *  - Login lookup: tenant BİLİNMEDEN email ile kullanıcı bulmanın TEK meşru yolu; SECURITY DEFINER
 *    fonksiyon sipario_auth (BYPASSRLS) yetkisiyle koşar ve yalnız login için gereken alanları döner.
 *  - RLS: tenants/users/devices tablolarında ENABLE + FORCE. Güvenli varsayılan: app.tenant_id
 *    set edilmemişse (veya boşsa) sıfır satır. FORCE, owner ile yanlışlıkla bağlanılsa bile izolasyonu korur.
 *  - Grant: runtime app rolüne (sipario_app) yalnız DML; tabloların sahibi owner kalır.
 *
 * personal_access_tokens'a RLS YOKTUR (auth altyapısı).
 */
return new class extends Migration
{
    public function up(): void
    {
        // --- 1) Login lookup fonksiyonu (cross-tenant tek okuma yüzeyi) -------------------
        DB::unprepared(<<<'SQL'
            CREATE OR REPLACE FUNCTION sipario_login_lookup(p_email text)
            RETURNS TABLE (
                id uuid, tenant_id uuid, name text, email text, password text,
                role text, status text, tenant_status text, valid_until timestamptz
            )
            LANGUAGE sql
            SECURITY DEFINER
            SET search_path = public
            AS $$
                SELECT u.id, u.tenant_id, u.name, u.email, u.password, u.role, u.status,
                       t.status, t.valid_until
                FROM users u
                JOIN tenants t ON t.id = u.tenant_id
                WHERE u.email = lower(p_email)
                LIMIT 1;
            $$;

            -- Fonksiyon gövdesi sipario_auth (BYPASSRLS) yetkisiyle koşsun diye sahibini değiştir.
            ALTER FUNCTION sipario_login_lookup(text) OWNER TO sipario_auth;
            REVOKE ALL ON FUNCTION sipario_login_lookup(text) FROM PUBLIC;
            GRANT EXECUTE ON FUNCTION sipario_login_lookup(text) TO sipario_app;

            -- BYPASSRLS RLS'i atlatır ama TABLO yetkisi ayrıdır: SECURITY DEFINER fonksiyon
            -- sipario_auth yetkisiyle koştuğundan, okuduğu tablolarda SELECT hakkı olmalı.
            GRANT SELECT ON users, tenants TO sipario_auth;
        SQL);

        // --- 2) RLS: her tabloda ENABLE + FORCE + tenant policy'si -----------------------
        // NULLIF(current_setting('app.tenant_id', true), '') → değişken yok/boşsa NULL → sıfır satır.
        DB::unprepared(<<<'SQL'
            ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
            ALTER TABLE tenants FORCE ROW LEVEL SECURITY;
            CREATE POLICY tenant_self ON tenants
                USING (id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                WITH CHECK (id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

            ALTER TABLE users ENABLE ROW LEVEL SECURITY;
            ALTER TABLE users FORCE ROW LEVEL SECURITY;
            CREATE POLICY tenant_isolation ON users
                USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

            ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
            ALTER TABLE devices FORCE ROW LEVEL SECURITY;
            CREATE POLICY tenant_isolation ON devices
                USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
        SQL);

        // --- 3) Runtime app rolüne DML yetkileri (sahip owner kalır) ---------------------
        DB::unprepared(<<<'SQL'
            GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sipario_app;
            GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sipario_app;

            -- Owner'ın bundan sonra yaratacağı tablolar için de otomatik DML yetkisi.
            ALTER DEFAULT PRIVILEGES FOR ROLE sipario_owner IN SCHEMA public
                GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sipario_app;
            ALTER DEFAULT PRIVILEGES FOR ROLE sipario_owner IN SCHEMA public
                GRANT USAGE, SELECT ON SEQUENCES TO sipario_app;
        SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
            ALTER DEFAULT PRIVILEGES FOR ROLE sipario_owner IN SCHEMA public
                REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM sipario_app;
            ALTER DEFAULT PRIVILEGES FOR ROLE sipario_owner IN SCHEMA public
                REVOKE USAGE, SELECT ON SEQUENCES FROM sipario_app;

            DROP POLICY IF EXISTS tenant_isolation ON devices;
            ALTER TABLE devices NO FORCE ROW LEVEL SECURITY;
            ALTER TABLE devices DISABLE ROW LEVEL SECURITY;

            DROP POLICY IF EXISTS tenant_isolation ON users;
            ALTER TABLE users NO FORCE ROW LEVEL SECURITY;
            ALTER TABLE users DISABLE ROW LEVEL SECURITY;

            DROP POLICY IF EXISTS tenant_self ON tenants;
            ALTER TABLE tenants NO FORCE ROW LEVEL SECURITY;
            ALTER TABLE tenants DISABLE ROW LEVEL SECURITY;

            REVOKE SELECT ON users, tenants FROM sipario_auth;
            DROP FUNCTION IF EXISTS sipario_login_lookup(text);
        SQL);
    }
};
