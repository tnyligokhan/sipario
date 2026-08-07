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

# Otomatik Migration ve Seed Betiği: Container kalkarken pgsql_owner ile migrate & seed koşar
USER root
RUN mkdir -p /etc/entrypoint.d && \
    echo '#!/bin/bash' > /etc/entrypoint.d/99-migrate.sh && \
    echo 'php /var/www/html/artisan migrate --database=pgsql_owner --force || true' >> /etc/entrypoint.d/99-migrate.sh && \
    echo 'php /var/www/html/artisan db:seed --force || true' >> /etc/entrypoint.d/99-migrate.sh && \
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
