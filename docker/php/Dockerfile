# ══════════════════════════════════════════════════════════════════════════════
#  Sipario — Üretim PHP imajı
# ══════════════════════════════════════════════════════════════════════════════
FROM composer:2 AS vendor

WORKDIR /build
COPY apps/api/composer.json apps/api/composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts \
    --no-progress

# ── Stage 2: Üretim çalışma zamanı ─────────────────────────────────────────
FROM serversideup/php:8.3-fpm-nginx

# Laravel AUTORUN ayarları
ENV AUTORUN_ENABLED="true" \
    AUTORUN_LARAVEL_MIGRATION="false" \
    AUTORUN_LARAVEL_STORAGE_LINK="true" \
    AUTORUN_LARAVEL_CONFIG_CACHE="true" \
    AUTORUN_LARAVEL_ROUTE_CACHE="true" \
    AUTORUN_LARAVEL_VIEW_CACHE="true" \
    AUTORUN_LARAVEL_EVENT_CACHE="true" \
    AUTORUN_LARAVEL_OPTIMIZE="false" \
    SSL_MODE="off" \
    PHP_OPCACHE_ENABLE="1" \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_MEMORY_LIMIT="256M"

WORKDIR /var/www/html

# Otomatik migration: container kalkarken şema pgsql_owner rolüyle güncellenir.
#
# ⚠️ İKİ ŞEY BİLİNÇLİ OLARAK KALDIRILDI (2026-08-09):
#
#   1. `db:seed` — her container başlangıcında ÜRETİM veritabanına DemoSeeder'ı basıyordu
#      (DatabaseSeeder → AdminUserSeeder + DemoSeeder). Yani canlı bayilerin yanına her
#      deploy'da demo bayisi ve sahte Bursa müşterileri yazılıyordu. Seed artık YALNIZ elle
#      çağrılır; hâlihazırda kurulu demo bayisi yerinde durur (mağaza incelemesi için gerekli).
#
#   2. `|| true` — migrate BAŞARISIZ olduğunda hatayı yutuyor ve container'ı "sağlıklı"
#      gösteriyordu. Uygulama eski şemayla ayağa kalkıyor, arıza günler sonra para
#      kayıtlarında görünüyordu. Bu, PLAN.md'de "sessiz arıza dersi" olarak yazılı olan
#      `saha-sunucu.ps1` hatasının (`*> $null` ile seeder hatasını yutmak) birebir tekrarıydı.
#      Artık `set -e`: migrate düşerse container BAŞLAMAZ ve arıza GÖRÜNÜR olur.
#
#      ⚠️ DÜRÜST OLMAK GEREKİRSE — OTOMATİK ROLLBACK YOK. Compose'daki `deploy.update_config`
#      (`order: start-first`, `failure_action: rollback`) alanları YALNIZ Docker Swarm'da
#      çalışır; Coolify düz `docker compose` kullandığı için bunlar SESSİZCE YOK SAYILIYOR.
#      Ölçüldü (2026-08-09): deploy sırasında site birkaç saniye 503 verdi — `start-first`
#      gerçekten uygulansaydı kesinti olmazdı. Yani migrate düşerse `restart: unless-stopped`
#      döngüye girer ve SİTE AŞAĞIDA KALIR; eski sürüme dönüş ELLE yapılır (Coolify'da önceki
#      deployment'a "Redeploy").
#
#      Bu takas bilinçli: bir defter uygulamasında GÖRÜNÜR bir kesinti, yanlış şemayla sessizce
#      çalışıp para kayıtlarını bozmaktan iyidir. Ama "rollback beni korur" diye güvenilmemeli.
#
# ⚠️ AÇIK RİSK — MIGRATION YARIŞI: `start-first` stratejisiyle eski ve yeni `app` container'ı
# kısa süre birlikte çalışır; ikisi de bu betiği koşar. Laravel migration'da süreçler arası
# kilit YOKTUR. Kalıcı çözüm migrate'i buradan alıp Coolify'ın post-deployment komutuna
# taşımaktır (tek sefer koşar). PLAN.md'de açık borç olarak duruyor.
USER root
RUN mkdir -p /etc/entrypoint.d && \
    printf '%s\n' \
      '#!/bin/bash' \
      'set -e' \
      'php /var/www/html/artisan migrate --database=pgsql_owner --force' \
      > /etc/entrypoint.d/99-migrate.sh && \
    chmod +x /etc/entrypoint.d/99-migrate.sh

# Uygulama kodunu kopyala
COPY --chown=www-data:www-data apps/api/ /var/www/html/
COPY --chown=www-data:www-data --from=vendor /build/vendor /var/www/html/vendor

# Storage ve cache izinleri
RUN mkdir -p \
        storage/framework/sessions \
        storage/framework/views \
        storage/framework/cache/data \
        storage/logs \
        bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache
USER www-data

EXPOSE 8080
