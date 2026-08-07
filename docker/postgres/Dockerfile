FROM postgres:16

# Rol ve init betiklerini doğrudan imajın içine kopyala
# (Coolify bind-mount sorunlarını ve boş klasör yoksaymalarını %100 engeller)
COPY docker/postgres/init/ /docker-entrypoint-initdb.d/

# Betik çalıştırma izinlerini garanti et
RUN chmod +x /docker-entrypoint-initdb.d/*.sh || true
