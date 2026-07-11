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
    END IF;
    -- Login lookup için RLS-atlayan yardımcı rol: SECURITY DEFINER fonksiyonun sahibi olur,
    -- kendisi LOGIN edemez (yalnız fonksiyon gövdesi onun yetkisiyle koşar).
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_auth') THEN
      CREATE ROLE sipario_auth NOLOGIN NOSUPERUSER BYPASSRLS;
    END IF;
  END \$\$;

  GRANT CONNECT ON DATABASE sipario TO sipario_app;
  GRANT USAGE ON SCHEMA public TO sipario_app;
EOSQL
