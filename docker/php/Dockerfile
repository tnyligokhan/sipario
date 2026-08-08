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

# ── MIGRATION BURADA KOŞMAZ — BİLİNÇLİ (2026-08-09) ──────────────────────────
#
# Şema güncellemesi Coolify'ın POST-DEPLOYMENT komutunda yapılıyor:
#     php artisan migrate --database=pgsql_owner --force     (hedef container: app)
# Bu, Coolify MCP üzerinden OKUNARAK doğrulandı — varsayım değil.
#
# Buradaki entrypoint kopyası KALDIRILDI çünkü aynı migration'ı İKİNCİ kez koşuyordu:
#   · Coolify komutu deploy başına BİR kez çalışır → doğru yer orası.
#   · Entrypoint ise HER container açılışında çalışır; `start-first` sırasında eski ve yeni
#     `app` birlikte ayaktayken ikisi birden migrate koşabilirdi. Laravel migration'da
#     süreçler arası kilit YOKTUR — bu gerçek bir yarıştı ve bugüne dek patlamaması şanstı.
#
# Hata görünürlüğü KAYBOLMADI, yer değiştirdi: post-deployment komutu düşerse Coolify deploy'u
# BAŞARISIZ işaretler. Yani eski `|| true`'nun açtığı "sessiz arıza" kapısı kapalı kalır —
# ki o hata, `saha-sunucu.ps1`in seeder çıktısını `*> $null` ile yutmasının birebir tekrarıydı.
#
# `db:seed` de aynı yoldan kaldırılmıştı: her container açılışında ÜRETİM veritabanına
# DemoSeeder basıyordu (DatabaseSeeder → AdminUserSeeder + DemoSeeder), yani canlı bayilerin
# yanına her deploy'da demo bayisi ve sahte müşteriler yazılıyordu. Seed artık yalnız elle
# çağrılır; kurulu demo bayisi yerinde durur (mağaza incelemesi için gerekli).
#
# ⚠️ OTOMATİK ROLLBACK YOK: compose'daki `deploy.update_config` (`start-first` +
# `failure_action: rollback`) yalnız Docker Swarm'da çalışır; Coolify düz `docker compose`
# kullandığı için sessizce yok sayılıyor. Ölçüldü: iki ayrı deploy'da site 40–60 sn 503 verdi.
# Geri dönüş ELLEDİR (Coolify → önceki deployment → Redeploy).
USER root

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
