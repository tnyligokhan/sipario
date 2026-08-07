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
  "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"
)

# REQUEST_INSTALL_PACKAGES KANALA GÖRE DEĞERLENDİRİLİR (2026-07-28):
#   saha   → İZİN MEŞRUDUR. Uygulama içi güncelleme indirilen APK'yı kurucuya verir; izin
#            olmadan özellik hiç çalışmaz. Bu kanal Play'e YÜKLENMEZ.
#   magaza → YASAK. Geçici saha özelliğinin mağaza sürümüne sızmaması bu satırla garanti
#            altındadır; unutma riski koda gömülüdür. Orada güncellemeyi Play yapar.
# Bu yüzden izin genel FORBIDDEN listesinden ÇIKARILDI ve aşağıda kanal bazında denetleniyor.
KURULUM_IZNI="android.permission.REQUEST_INSTALL_PACKAGES"

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

# ── Kanal kuralı: kurulum izni yalnız `saha`da ────────────────────────────────────────────
# Kanal, birleştirilmiş manifest'in YOLUNDAN okunur (ör. .../merged_manifests/sahaRelease/...).
# Yol kanal adı içermiyorsa (flavor'sız eski derleme) kural MAĞAZA gibi uygulanır — güvenli
# varsayılan: izni beklemediğimiz her yerde varlığı ihlaldir.
kanal="bilinmeyen"
case "$MANIFEST" in
  *merged_manifests/saha*|*merged_manifests/Saha*) kanal="saha" ;;
  *merged_manifests/magaza*|*merged_manifests/Magaza*) kanal="magaza" ;;
esac
echo "Kanal: $kanal"

if grep -q "uses-permission[^>]*\"$KURULUM_IZNI\"" "$MANIFEST"; then
  if [[ "$kanal" != "saha" ]]; then
    echo "  IHLAL: $KURULUM_IZNI '$kanal' kanalında beyan edilmiş" >&2
    echo "         Bu izin YALNIZ saha kanalına aittir (uygulama içi güncelleme)." >&2
    echo "         Mağaza sürümünde bulunması Play politikası açısından gereksiz risktir." >&2
    violations=$((violations + 1))
  fi
elif [[ "$kanal" == "saha" ]]; then
  # Pozitif kontrol: saha kanalında izin YOKSA güncelleme sessizce kurulamaz — indirme
  # biter, kurulum ekranı hiç açılmaz ve bayi "güncellenmedi" der. Sessiz ölümü burada kırıyoruz.
  echo "HATA: saha kanalında $KURULUM_IZNI YOK — indirilen APK kurulamaz." >&2
  echo "      Kaynak: apps/mobile/android/app/src/saha/AndroidManifest.xml" >&2
  exit 1
fi

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
