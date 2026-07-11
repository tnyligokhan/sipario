#!/bin/bash
# Test veritabanı. Testler ayrı bir DB'ye (sipario_test) koşar ki dev verisini (sipario) ezmesin.
# Roller (10-roles.sh) küme düzeyinde olduğundan her iki DB'de de geçerlidir; burada yalnız
# test DB'sini oluşturup app rolüne CONNECT veriyoruz. Yalnız ilk initdb'de koşar.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  SELECT 'CREATE DATABASE sipario_test OWNER sipario_owner'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'sipario_test')\gexec
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname sipario_test <<-EOSQL
  GRANT CONNECT ON DATABASE sipario_test TO sipario_app;
  GRANT USAGE ON SCHEMA public TO sipario_app;
EOSQL
