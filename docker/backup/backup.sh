#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  Sipario — Günlük PostgreSQL yedekleme betiği
# ══════════════════════════════════════════════════════════════════════════════
#
#  Bu betik backup sidecar container'ında çalışır (postgres:16 imajı).
#  pg_dump ile günlük tam yedek alır ve eski yedekleri saklama politikasına
#  göre temizler.
#
#  SAKLAMA POLİTİKASI:
#    - Günlük:  Son 7 gün korunur
#    - Haftalık: Son 4 Pazar günü korunur
#    - Aylık:   Son 6 ayın 1'i korunur
#
#  ORTAM DEĞİŞKENLERİ (docker-compose.prod.yml'den gelir):
#    PGHOST, PGUSER, PGPASSWORD, PGDATABASE
#
#  YEDEK FORMATI: /backups/daily/sipario_YYYYMMDD_HHMMSS.sql.gz
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

BACKUP_DIR="/backups"
DAILY_DIR="${BACKUP_DIR}/daily"
WEEKLY_DIR="${BACKUP_DIR}/weekly"
MONTHLY_DIR="${BACKUP_DIR}/monthly"

# Saklama süreleri
DAILY_KEEP=7
WEEKLY_KEEP=4
MONTHLY_KEEP=6

# Yedekleme aralığı (saniye) — 24 saat
INTERVAL=86400

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Dizinleri oluştur
mkdir -p "${DAILY_DIR}" "${WEEKLY_DIR}" "${MONTHLY_DIR}"

do_backup() {
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename="sipario_${timestamp}.sql.gz"
    local filepath="${DAILY_DIR}/${filename}"

    log "Yedekleme başlıyor: ${filename}"

    # pg_dump ile sıkıştırılmış tam yedek
    if pg_dump --no-owner --no-privileges --clean --if-exists | gzip > "${filepath}"; then
        local size
        size=$(du -h "${filepath}" | cut -f1)
        log "✅ Yedekleme tamamlandı: ${filename} (${size})"
    else
        log "❌ Yedekleme BAŞARISIZ!"
        rm -f "${filepath}"
        return 1
    fi

    # Haftalık kopya (Pazar günü ise)
    if [ "$(date '+%u')" -eq 7 ]; then
        cp "${filepath}" "${WEEKLY_DIR}/${filename}"
        log "📅 Haftalık kopya oluşturuldu"
    fi

    # Aylık kopya (ayın 1'i ise)
    if [ "$(date '+%d')" -eq 1 ] || [ "$(date '+%d')" = "01" ]; then
        cp "${filepath}" "${MONTHLY_DIR}/${filename}"
        log "📅 Aylık kopya oluşturuldu"
    fi
}

cleanup() {
    log "Eski yedekler temizleniyor..."

    # Günlük: DAILY_KEEP'ten eski olanları sil
    local count
    count=$(find "${DAILY_DIR}" -name "*.sql.gz" -type f | wc -l)
    if [ "${count}" -gt "${DAILY_KEEP}" ]; then
        find "${DAILY_DIR}" -name "*.sql.gz" -type f | sort | head -n -${DAILY_KEEP} | xargs rm -f
        log "  Günlük: $(( count - DAILY_KEEP )) eski yedek silindi"
    fi

    # Haftalık
    count=$(find "${WEEKLY_DIR}" -name "*.sql.gz" -type f | wc -l)
    if [ "${count}" -gt "${WEEKLY_KEEP}" ]; then
        find "${WEEKLY_DIR}" -name "*.sql.gz" -type f | sort | head -n -${WEEKLY_KEEP} | xargs rm -f
        log "  Haftalık: $(( count - WEEKLY_KEEP )) eski yedek silindi"
    fi

    # Aylık
    count=$(find "${MONTHLY_DIR}" -name "*.sql.gz" -type f | wc -l)
    if [ "${count}" -gt "${MONTHLY_KEEP}" ]; then
        find "${MONTHLY_DIR}" -name "*.sql.gz" -type f | sort | head -n -${MONTHLY_KEEP} | xargs rm -f
        log "  Aylık: $(( count - MONTHLY_KEEP )) eski yedek silindi"
    fi
}

# ── Ana döngü ────────────────────────────────────────────────────────────────
log "Yedekleme servisi başladı (aralık: ${INTERVAL}s)"
log "Saklama: ${DAILY_KEEP} günlük, ${WEEKLY_KEEP} haftalık, ${MONTHLY_KEEP} aylık"

# İlk başlangıçta hemen bir yedek al
do_backup
cleanup

# Sonrasında döngüye gir
while true; do
    sleep "${INTERVAL}"
    do_backup
    cleanup
done
