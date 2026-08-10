#!/bin/bash
# Sipario runtime rolleri — rol parolalarının TEK kaynağı.
#
# Bu betik İKİ yerden koşar:
#   1) initdb sırasında (/docker-entrypoint-initdb.d) — hacim BOŞken, rolleri kurmak için
#   2) HER container açılışında (sipario-rol-esitle.sh) — parola döndüğünde rolü hizalamak için
#
# (2) PAZARLIKSIZ. 2026-08-10'da bunun yokluğu üretimi düşürdü: DB_PASSWORD döndürüldü, ama
# initdb yalnız BOŞ hacimde koştuğu için roldeki parola eski değerinde dondu. Uygulama yeni
# anahtarla eski kilidi açmaya çalıştı → "password authentication failed" → queue çöktü →
# Coolify 10. yeniden başlatmada uygulamayı durdurdu → temizlik `external` ağı sildi →
# sonraki HER deploy "network declared as external, but could not be found" ile öldü.
# Zincirin tamamı tek bir eksikten doğdu: parolayı değiştirmek rolü değiştirmiyordu.
#
# Parola değişkenleri, uygulamanın BAĞLANDIĞI adların ta kendisidir (apps/api/config/database.php):
#   pgsql       -> DB_PASSWORD        (sipario_app)
#   pgsql_panel -> DB_PANEL_PASSWORD  (sipario_panel)
#   pgsql_owner -> DB_OWNER_PASSWORD  (sipario_owner = POSTGRES_USER)
# İkinci bir ad (eski SIPARIO_APP_PASSWORD gibi) BİLEREK YOK: aynı sırrın iki adı varsa
# bir gün biri güncellenip diğeri kalır ve fark yalnız üretimde görünür.
#
# Amaç (DECISIONS + architect §2): uygulama ve testler superuser/BYPASSRLS OLMAYAN bir
# rolle bağlanır ki RLS gerçekten uygulansın ve izolasyon kanıtlanabilsin.
# Parolalar env'den okunur; migration'a veya repoya sır yazılmaz.
set -euo pipefail

# BOŞ PAROLA SESSİZCE GEÇMEZ. Boş bir parolayla ALTER ROLE başarılı olur ve rol,
# scram ile ASLA doğrulanamayan bir hâle düşer — yani tam da önlemeye çalıştığımız
# arızayı, üstelik daha sessiz biçimde üretir.
for degisken in DB_PASSWORD DB_PANEL_PASSWORD DB_OWNER_PASSWORD; do
  if [ -z "${!degisken:-}" ]; then
    echo "HATA: $degisken boş — rol parolaları hizalanamaz." >&2
    exit 1
  fi
done

# Parolalar SQL'e string olarak GÖMÜLMEZ; psql değişkeni (:'...') olarak geçirilir.
# Gömseydik, içinde tek tırnak geçen bir parola SQL'i bozar veya sessizce yanlış
# parola yazardı.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=app_pw="$DB_PASSWORD" \
  --set=panel_pw="$DB_PANEL_PASSWORD" \
  --set=owner_pw="$DB_OWNER_PASSWORD" \
  --set=owner_role="$POSTGRES_USER" <<-'EOSQL'
	DO $$ BEGIN
	  -- Runtime uygulama rolü: sahibi DEĞİL, superuser DEĞİL, BYPASSRLS DEĞİL → RLS ona uygulanır.
	  -- Parola burada VERİLMEZ: psql, dolar-tırnaklı blok içinde değişken yerleştirmez.
	  -- Bu yüzden yaratma ile parola atama bilerek ayrıldı (aşağıdaki ALTER'lar).
	  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_app') THEN
	    CREATE ROLE sipario_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
	  END IF;

	  -- Login lookup için RLS-atlayan yardımcı rol (NOLOGIN → parolası yok, olması da gerekmez)
	  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_auth') THEN
	    CREATE ROLE sipario_auth NOLOGIN NOSUPERUSER BYPASSRLS;
	  END IF;

	  -- Yönetim paneli rolü
	  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sipario_panel') THEN
	    CREATE ROLE sipario_panel LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE BYPASSRLS;
	  END IF;
	END $$;

	-- HER KOŞUDA hizala. Rol zaten varsa da parola env'deki değere ÇEKİLİR —
	-- betiğin her açılışta koşmasının tek sebebi bu üç satırdır.
	ALTER ROLE sipario_app   WITH PASSWORD :'app_pw';
	ALTER ROLE sipario_panel WITH PASSWORD :'panel_pw';
	ALTER ROLE :"owner_role" WITH PASSWORD :'owner_pw';
EOSQL

# GRANT'lar ayrı koşuyor: veritabanı adı POSTGRES_DB'den gelir, owner rolünden değil.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=db_name="$POSTGRES_DB" <<-'EOSQL'
	GRANT CONNECT ON DATABASE :"db_name" TO sipario_app;
	GRANT USAGE ON SCHEMA public TO sipario_app;
	GRANT CONNECT ON DATABASE :"db_name" TO sipario_panel;
	GRANT USAGE ON SCHEMA public TO sipario_panel;
EOSQL
