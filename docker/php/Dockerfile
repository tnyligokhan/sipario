# ══════════════════════════════════════════════════════════════════════════════
#  Sipario — Üretim PHP imajı
# ══════════════════════════════════════════════════════════════════════════════
#
#  NEDEN serversideup/php?
#    - PHP-FPM + Nginx tek container'da, sıfır yapılandırma
#    - pdo_pgsql, opcache, intl, gd, zip, bcmath dahil
#    - AUTORUN_* env değişkenleriyle Laravel optimizasyonu otomatik
#    - Unprivileged (www-data) — güvenlik varsayılanı doğru
#
#  NEDEN Node.js BUILD YOK?
#    - @vite yalnız kullanılmayan welcome.blade.php'de
#    - Site CSS → public/css/site.css (statik dosya)
#    - Panel CSS → public/css/panel.css (statik dosya)
#    - Alpine.js → public/js/alpine.js (statik dosya)
#    - Livewire JS → composer paketi tarafından sunulur (@livewireScripts)
#
#  NEDEN AUTORUN_LARAVEL_MIGRATION = false?
#    - app, queue, scheduler aynı anda ayağa kalkıyor
#    - Üçü birden migrate koşarsa race condition olur
#    - Migration pgsql_owner bağlantısını GEREKTİRİR (DDL yetkileri)
#    - Çözüm: Coolify post-deployment hook ile TEK SEFER çalıştırılır
#
#  NEDEN SSL_MODE = off?
#    - TLS sonlandırması Coolify Traefik'te yapılır
#    - Container'a HTTP:8080 gelir, HTTPS gereksiz
#
#  PORT 8080: serversideup unprivileged çalıştığı için 80 yerine 8080 dinler
# ══════════════════════════════════════════════════════════════════════════════

# ── Stage 1: Composer bağımlılıkları ────────────────────────────────────────
FROM composer:2 AS vendor

WORKDIR /build

# Önce yalnız manifest kopyala — bağımlılık değişmedikçe katman önbellekte kalır
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

# Laravel AUTORUN ayarları (container başlangıcında otomatik çalışır)
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

# Uygulama kodunu kopyala (build context = repo kökü, .dockerignore filtreler)
COPY --chown=www-data:www-data apps/api/ /var/www/html/

# Composer vendor dizinini build stage'den kopyala
COPY --chown=www-data:www-data --from=vendor /build/vendor /var/www/html/vendor

# Storage ve cache dizinlerinin yazılabilirliğini garanti et
USER root
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
