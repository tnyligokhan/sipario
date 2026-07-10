#!/usr/bin/env bash
# Kırmızı çizgi #6'nın otomatik denetimi.
#
# Play'in kısıtlı SMS/Call Log izin grubundan hiçbir izin uygulamaya girmemeli.
# Kendi manifest'imizde olmaması yetmez: üçüncü parti paketler manifest merger
# üzerinden izin enjekte eder ve bu ancak BİRLEŞTİRİLMİŞ manifest'te görünür.
# Bu yüzden denetim kaynak dosyayı değil, build çıktısını okur.
#
# Kullanım:  scripts/check_permissions.sh [debug|release]
# CI'da build sonrası çalışır; ihlalde build kırılır.

set -euo pipefail

VARIANT="${1:-debug}"
MOBILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../apps/mobile" && pwd)"

FORBIDDEN=(
  "android.permission.READ_CALL_LOG"
  "android.permission.WRITE_CALL_LOG"
  "android.permission.PROCESS_OUTGOING_CALLS"
  "android.permission.READ_PHONE_STATE"
  "android.permission.READ_PHONE_NUMBERS"
  "android.permission.ANSWER_PHONE_CALLS"
  "android.permission.READ_SMS"
  "android.permission.RECEIVE_SMS"
  "android.permission.SEND_SMS"
  "android.permission.REQUEST_INSTALL_PACKAGES"
  "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"
)

MANIFEST="$(find "$MOBILE_DIR/build" -path "*merged_manifests*${VARIANT}*" -name "AndroidManifest.xml" 2>/dev/null | head -1)"

if [[ -z "$MANIFEST" ]]; then
  echo "HATA: birleştirilmiş manifest bulunamadı. Önce derleyin:" >&2
  echo "       cd apps/mobile && flutter build apk --$VARIANT" >&2
  exit 2
fi

echo "Denetlenen manifest: ${MANIFEST#"$MOBILE_DIR/"}"

violations=0
for perm in "${FORBIDDEN[@]}"; do
  # tools:node="remove" satırları kaynak manifest'te kalır ama birleştirilmiş
  # çıktıda uses-permission olarak görünmez; burada gerçek beyanları arıyoruz.
  if grep -q "uses-permission[^>]*\"$perm\"" "$MANIFEST"; then
    echo "  IHLAL: $perm beyan edilmiş" >&2
    violations=$((violations + 1))
  fi
done

if [[ $violations -gt 0 ]]; then
  echo "" >&2
  echo "$violations yasaklı izin bulundu. Kırmızı çizgi #6 ihlal ediliyor." >&2
  echo "Kaynağı bulmak için:  cd apps/mobile/android && ./gradlew :app:processDebugMainManifest --info" >&2
  echo "Çözüm: ilgili izni AndroidManifest.xml'e tools:node=\"remove\" ile ekleyin." >&2
  exit 1
fi

# CallScreeningService gerçekten beyan edilmiş mi? Kaldırılırsa arayan tanıma sessizce ölür.
if ! grep -q "android.telecom.CallScreeningService" "$MANIFEST"; then
  echo "HATA: CallScreeningService beyanı manifest'te yok — arayan tanıma çalışmaz." >&2
  exit 1
fi

# READ_CONTACTS zorunlu. Telecom'un CallScreeningServiceFilter'ı, bu izne sahip olmayan
# tarama uygulamasını rehberde KAYITLI numaralardan gelen çağrılarda hiç uyandırmaz:
#     if (priorStageResult.contactExists && !hasReadContactsPermission()) { atla }
# İzin manifest'ten düşerse hata sessizdir: uygulama çalışır, testler geçer, ama bayinin
# rehberine kaydettiği (yani en sık aradığı) müşterilerde kart çıkmaz. Gerçek cihazda
# doğrulandı: izinle birlikte "contact exists" olan çağrıda da SCREENING_BOUND alınıyor.
if ! grep -q "uses-permission[^>]*\"android.permission.READ_CONTACTS\"" "$MANIFEST"; then
  echo "HATA: READ_CONTACTS beyanı yok." >&2
  echo "      Rehberde kayıtlı müşteriler aradığında arayan tanıma SESSİZCE çalışmaz." >&2
  exit 1
fi

echo "Temiz: yasaklı izin yok, CallScreeningService ve READ_CONTACTS yerinde."
