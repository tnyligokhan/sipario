#!/usr/bin/env bash
# Sipario — otomatik commit kapısı
# Claude her yanıtı bitirdiğinde çalışır. Kapıdan geçerse commit+push, geçmezse sessizce çıkar.
# ASLA exit 2 dönmez -> Claude'u sonsuz döngüye sokmaz.

set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

# --- 0. Sonsuz döngü koruması -------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
    exit 0
  fi
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

log() { echo "[kapi] $*" >&2; }

# --- 1. Değişiklik yoksa iş yok ----------------------------------------------
if [ -z "$(git status --porcelain)" ]; then
  exit 0
fi

# --- 2. Branch koruması: main/master'a otomatik commit YOK -------------------
BRANCH="$(git branch --show-current 2>/dev/null || echo '')"
case "$BRANCH" in
  main|master|"")
    log "main/master üzerindesin — otomatik commit yapılmadı. Çalışma dalına geç."
    exit 0
    ;;
esac

# --- 3. Sır taraması (en sert kapı) ------------------------------------------
if git status --porcelain | grep -qE '(^|/)\.env($|[^.])'; then
  log "RED: .env dosyası staged/untracked. Commit yok."
  exit 0
fi

if grep -rInE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor \
     --exclude='*.example' --exclude='auto-commit.sh' \
     '(APP_KEY=[^[:space:]]|DB_PASSWORD=[^[:space:]]|BEGIN [A-Z ]*PRIVATE KEY)' . >/dev/null 2>&1; then
  log "RED: repoda sır kalıbı bulundu. Commit yok."
  exit 0
fi

# --- 4. Kalite kapıları (araç yoksa atlanır, uydurma başarı yok) -------------
FAIL=0

if [ -f composer.json ]; then
  if [ -x vendor/bin/pint ];    then vendor/bin/pint --test    >/dev/null 2>&1 || { log "RED: pint";    FAIL=1; }; fi
  if [ -x vendor/bin/phpstan ]; then vendor/bin/phpstan analyse --no-progress >/dev/null 2>&1 || { log "RED: phpstan"; FAIL=1; }; fi
  if [ -x vendor/bin/pest ];    then vendor/bin/pest           >/dev/null 2>&1 || { log "RED: pest";    FAIL=1; }; fi
fi

if [ -f pubspec.yaml ] && command -v flutter >/dev/null 2>&1; then
  flutter analyze >/dev/null 2>&1 || { log "RED: flutter analyze"; FAIL=1; }
  if [ -d test ]; then flutter test >/dev/null 2>&1 || { log "RED: flutter test"; FAIL=1; }; fi
fi

if [ -x ./security-lint.sh ]; then
  ./security-lint.sh >/dev/null 2>&1 || { log "RED: security-lint"; FAIL=1; }
fi

if [ "$FAIL" -ne 0 ]; then
  log "Kapı kapalı — commit yok. Önce testleri yeşile çevir."
  exit 0
fi

# --- 5. Commit + push --------------------------------------------------------
STAMP="$(date '+%Y-%m-%d %H:%M')"
FILES="$(git status --porcelain | wc -l | tr -d ' ')"
LAST_DECISION=""
[ -f DECISIONS.md ] && LAST_DECISION="$(tail -n 1 DECISIONS.md | cut -c1-60)"

git add -A
git commit -q -m "auto: ${FILES} dosya güncellendi (${STAMP})" \
           -m "${LAST_DECISION:-otomatik kapı: testler yeşil}" || exit 0

if git remote get-url origin >/dev/null 2>&1; then
  git push -q origin "$BRANCH" 2>/dev/null || log "push başarısız (uzak dal yok olabilir)"
fi

log "YEŞİL: commit + push tamam (${BRANCH})"
exit 0
