#!/usr/bin/env bash
# Kırmızı çizgi #6 — KAYNAK manifest izin denetimi (Flutter/gradle GEREKTİRMEZ, CI'da build'siz koşar).
#
# İki katmanlı savunmanın hafif katmanı. check_permissions.sh BİRLEŞTİRİLMİŞ manifest'i (3. parti
# paketlerin manifest-merger ile enjekte ettiği izinler) build sonrası denetler ve tam Android
# derleme ortamı ister. Bu script ise KAYNAK AndroidManifest.xml'i build'siz denetler: kendi
# manifest'imizde bir yasaklı izin plain (tools:node="remove" olmadan) beyan edilirse ya da
# READ_CONTACTS / CallScreeningService düşerse yakalar — en sık regresyon budur ve mobil CI
# kurulana dek tek otomatik bekçidir. Merger-enjeksiyonu HÂLÂ check_permissions.sh'in işidir.
#
# Kullanım:  scripts/check_permissions_source.sh
# Çıkış: 0 temiz, 1 ihlal, 2 dosya yok. CI'da doğrudan çağrılır.

set -euo pipefail

MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/apps/mobile/android/app/src/main/AndroidManifest.xml"
[[ -f "$MANIFEST" ]] || { echo "HATA: kaynak manifest yok: $MANIFEST" >&2; exit 2; }

# Play'in kısıtlı SMS/Call Log grubu + yan-yükleme riskli izinler. Bunlardan biri KAYNAK manifest'te
# plain (tools:node="remove"'suz) uses-permission olarak görünürse kırmızı çizgi #6 ihlal edilir.
FORBIDDEN=(
  READ_CALL_LOG WRITE_CALL_LOG PROCESS_OUTGOING_CALLS
  READ_PHONE_STATE READ_PHONE_NUMBERS ANSWER_PHONE_CALLS
  READ_SMS RECEIVE_SMS SEND_SMS
  REQUEST_INSTALL_PACKAGES REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
)

violations=0
for perm in "${FORBIDDEN[@]}"; do
  # Bu izni içeren uses-permission satırlarını al; her biri tools:node="remove" taşımalı.
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! grep -q 'tools:node="remove"' <<<"$line"; then
      echo "  IHLAL: android.permission.$perm plain beyan edilmiş (tools:node=\"remove\" yok)" >&2
      violations=$((violations + 1))
    fi
  done < <(grep "uses-permission[^>]*\"android.permission.$perm\"" "$MANIFEST" || true)
done

# READ_CONTACTS zorunlu: düşerse rehberdeki müşteriler aradığında arayan tanıma SESSİZCE çalışmaz.
if ! grep -q 'uses-permission[^>]*"android.permission.READ_CONTACTS"' "$MANIFEST"; then
  echo "HATA: READ_CONTACTS beyanı yok — rehberdeki müşterilerde arayan tanıma sessizce ölür." >&2
  violations=$((violations + 1))
fi

# CallScreeningService düşerse arayan tanıma tamamen ölür.
if ! grep -q 'android.telecom.CallScreeningService' "$MANIFEST"; then
  echo "HATA: CallScreeningService beyanı yok — arayan tanıma çalışmaz." >&2
  violations=$((violations + 1))
fi

if [[ $violations -gt 0 ]]; then
  echo "" >&2
  echo "$violations sorun bulundu (kaynak manifest). Kırmızı çizgi #6." >&2
  echo "Yasaklı izin için: AndroidManifest.xml'de tools:node=\"remove\" ile sökün." >&2
  exit 1
fi

echo "Kaynak manifest temiz: yasaklı izinler tools:node=remove ile sökülü, READ_CONTACTS + CallScreeningService yerinde."
