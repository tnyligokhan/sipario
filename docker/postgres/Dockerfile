FROM postgres:16

# Rol ve init betiklerini doğrudan imajın içine kopyala
# (Coolify bind-mount sorunlarını ve boş klasör yoksaymalarını %100 engeller)
COPY docker/postgres/init/ /docker-entrypoint-initdb.d/

# Rol eşitleyici: initdb YALNIZ boş hacimde koştuğu için, parola döndürüldüğünde rolü
# hizalayacak ikinci bir yol gerekir. 2026-08-10 kesintisinin tek sebebi bunun yokluğuydu.
COPY docker/postgres/sipario-rol-esitle.sh /usr/local/bin/sipario-rol-esitle.sh
COPY docker/postgres/sipario-entrypoint.sh /usr/local/bin/sipario-entrypoint.sh

# Betik çalıştırma izinlerini garanti et
RUN chmod +x /docker-entrypoint-initdb.d/*.sh \
             /usr/local/bin/sipario-rol-esitle.sh \
             /usr/local/bin/sipario-entrypoint.sh

# CMD taban imajdan devralınır ("postgres") ve sarmalayıcıya argüman olarak geçer.
ENTRYPOINT ["/usr/local/bin/sipario-entrypoint.sh"]
CMD ["postgres"]
