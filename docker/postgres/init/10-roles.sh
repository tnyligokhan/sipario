#!/bin/bash
# Sipario runtime rolleri. Bu betik yalnız veri volume'u BOŞken (ilk initdb'de) koşar.
# Amaç (DECISIONS + architect §2): uygulama ve testler superuser/BYPASSRLS OLMAYAN bir
# rolle bağlanır ki RLS gerçekten uygulansın ve izolasyon kanıtlanabilsin.
# Parolalar env'den okunur; migration'a veya repoya sır yazılmaz.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  DO \$\$ BEGIN
    -- Runtime uygulama rolü: sahibi DEĞİL, superuser DEĞİL, BYPASSRLS DEĞİL → RLS ona uygulanır.
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_app') THEN
      CREATE ROLE sipario_app LOGIN PASSWORD '${SIPARIO_APP_PASSWORD}'
        NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
    ELSE
      ALTER ROLE sipario_app WITH PASSWORD '${SIPARIO_APP_PASSWORD}';
    END IF;

    -- Login lookup için RLS-atlayan yardımcı rol
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_auth') THEN
      CREATE ROLE sipario_auth NOLOGIN NOSUPERUSER BYPASSRLS;
    END IF;

    -- Yönetim paneli rolü
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_panel') THEN
      CREATE ROLE sipario_panel LOGIN PASSWORD '${SIPARIO_PANEL_PASSWORD}'
        NOSUPERUSER NOCREATEDB NOCREATEROLE BYPASSRLS;
    ELSE
      ALTER ROLE sipario_panel WITH PASSWORD '${SIPARIO_PANEL_PASSWORD}';
    END IF;
  END \$\$;

  GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO sipario_app;
  GRANT USAGE ON SCHEMA public TO sipario_app;
  GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO sipario_panel;
  GRANT USAGE ON SCHEMA public TO sipario_panel;
EOSQL
