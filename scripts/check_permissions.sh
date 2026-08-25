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

# REQUEST_INSTALL_PACKAGES KANALA GÖRE DEĞERLENDİRİLİR (2026-07-28; deneme eklendi 2026-08-09):
#   saha   → İZİN MEŞRUDUR. Uygulama içi güncelleme indirilen APK'yı kurucuya verir; izin
#            olmadan özellik hiç çalışmaz. Bu kanal Play'e YÜKLENMEZ.
#   deneme → İZİN MEŞRUDUR. Aynı gerekçe: geliştirme ekibinin cihazı da kendini güncelliyor.
#            Bu kanal da Play'e YÜKLENMEZ (applicationId `.test` sonekli, ayrı uygulama).
#   magaza → YASAK. Geçici saha özelliğinin mağaza sürümüne sızmaması bu satırla garanti
#            altındadır; unutma riski koda gömülüdür. Orada güncellemeyi Play yapar.
# Bu yüzden izin genel FORBIDDEN listesinden ÇIKARILDI ve aşağıda kanal bazında denetleniyor.
KURULUM_IZNI="android.permission.REQUEST_INSTALL_PACKAGES"

# FLAVOR'LU manifest ÖNCELİKLİDİR (2026-08-09 düzeltmesi).
#
# ⚠️ ÖNCEKİ HÂLİ SESSİZCE YANLIŞ DOSYAYI DENETLİYORDU: `find ... | head -1` eski, flavor'sız bir
# derlemeden kalan `merged_manifests/release/...` yolunu seçebiliyor ve betik "Temiz" diyordu —
# oysa gerçek ürün `sahaRelease`/`denemeRelease`/`magazaRelease` çıktısıydı. Yani Play uyumunu
# GARANTİ ETMESİ beklenen kapı, hiç üretilmeyen bir yapıya bakıp onay veriyordu. Bu depoda aynı
# hata sınıfı bugün iki kez daha ödendi (tanınmayan kanal → yanlış alarm, miras healthcheck →
# alarm körlüğü); bir kapı neyi denetlediğini bilmiyorsa güvence değil GÜRÜLTÜDÜR.
#
# ⚠️ `|| true` PAZARLIKSIZ: bu betik `set -euo pipefail` ile koşuyor ve `head -1` ilk satırı
# alınca boruyu kapatıyor → `find`/`grep` SIGPIPE alıyor → pipefail yüzünden komut ikamesi
# başarısız sayılıyor → betik TEK SATIR ÇIKTI VERMEDEN ölüyor. Bizzat yaşandı: düzeltmenin ilk
# hâli hiçbir şey basmadan 1 döndürdü. Bir denetim betiğinin sessizce ölmesi, "temiz" demesinden
# beterdir — çağıran taraf farkı anlamaz.
# ⚠️ `-ipath` (BÜYÜK/KÜÇÜK HARF DUYARSIZ) — 2026-08-09'da bulunan SESSİZ KÖRLÜK.
#
# Eski satır `-path "*merged_manifests*${VARIANT}*"` yazıyordu ve `find -path` harf duyarlıdır.
# Flavor'lu çıktıların yolu `merged_manifests/sahaRelease/...`, yani "release" DEĞİL "Release"
# geçer. Dolayısıyla desen flavor'lu hiçbir manifest'i EŞLEŞTİRMİYOR, yalnız flavor'sız eski
# `merged_manifests/release/...` kalıntısını buluyor ve betik onun üzerinden "Temiz" diyordu.
# Sonuç: Play uyumunu garanti etmesi beklenen kapı, GERÇEK ÜRÜNE hiç bakmamış. Kırmızı çizgi
# #6'nın otomatik denetimi tam olarak burada delikti.
#
# `|| true` de pazarlıksız: `set -euo pipefail` altında `head`/`grep` boruyu kapatınca SIGPIPE
# oluşuyor ve betik TEK SATIR ÇIKTI VERMEDEN ölüyor (bizzat yaşandı). Sessizce ölen bir denetim,
# "temiz" diyeninden beterdir — çağıran taraf farkı anlamaz.
MANIFESTLER=()
while IFS= read -r yol; do
  [[ -n "$yol" ]] && MANIFESTLER+=("$yol")
done < <( { find "$MOBILE_DIR/build" -ipath "*merged_manifests*${VARIANT}*" -name "AndroidManifest.xml" 2>/dev/null \
  | grep -Ei "merged_manifests/(saha|deneme|magaza)" | sort -u; } || true )

if [[ ${#MANIFESTLER[@]} -eq 0 ]]; then
  echo "HATA: flavor'lu birleştirilmiş manifest bulunamadı. Önce derleyin:" >&2
  echo "       cd apps/mobile && flutter build apk --$VARIANT --flavor saha|deneme|magaza" >&2
  echo "       (Flavor'suz derleme denetlenmez: kanal okunamadan kurulum izninin meşruluğu" >&2
  echo "        söylenemez ve depo kuralı zaten 'her zaman --flavor verilir'dir.)" >&2
  exit 2
fi

# HEPSİ denetlenir, ilki değil. Tek manifest'e bakmak "hangisine baktım?" sorusunu açık
# bırakıyordu; üç kanal da üretildiyse üçü de kendi kuralıyla sınanmalı.
violations=0
for MANIFEST in "${MANIFESTLER[@]}"; do
  kanal="bilinmeyen"
  case "$MANIFEST" in
    *[Mm]erged_manifests/saha*) kanal="saha" ;;
    *[Mm]erged_manifests/deneme*) kanal="deneme" ;;
    *[Mm]erged_manifests/magaza*) kanal="magaza" ;;
  esac

  echo "── Kanal: $kanal — ${MANIFEST#"$MOBILE_DIR/"}"

  for perm in "${FORBIDDEN[@]}"; do
    # tools:node="remove" satırları kaynak manifest'te kalır ama birleştirilmiş
    # çıktıda uses-permission olarak görünmez; burada gerçek beyanları arıyoruz.
    if grep -q "uses-permission[^>]*\"$perm\"" "$MANIFEST"; then
      echo "  IHLAL [$kanal]: $perm beyan edilmiş" >&2
      violations=$((violations + 1))
    fi
  done

  # Kendi kendini güncelleyen kanallar — izin BURALARDA meşru, başka her yerde ihlal.
  # `deneme` 2026-08-09'da eklendi; eklenmeseydi bu betik deneme derlemesinde YANLIŞ ALARM
  # verirdi (izin var, kanal tanınmıyor → ihlal sayılır) ve gerçek ihlalleri gizleyen bir
  # gürültü kaynağına dönüşürdü. Aynı gün, tanınmayan bir sağlık kontrolünün bütün paneli
  # kırmızıya boyayıp GERÇEK bir çöküşü görünmez yapması bu dersi zaten ödetmişti.
  case "$kanal" in
    saha|deneme) guncelleyen_kanal=1 ;;
    *) guncelleyen_kanal=0 ;;
  esac

  if grep -q "uses-permission[^>]*\"$KURULUM_IZNI\"" "$MANIFEST"; then
    if [[ $guncelleyen_kanal -eq 0 ]]; then
      echo "  IHLAL [$kanal]: $KURULUM_IZNI beyan edilmiş" >&2
      echo "         Bu izin YALNIZ saha/deneme kanallarına aittir (uygulama içi güncelleme)." >&2
      echo "         Mağaza sürümünde bulunması Play politikası açısından gereksiz risktir." >&2
      violations=$((violations + 1))
    fi
  elif [[ $guncelleyen_kanal -eq 1 ]]; then
    # Pozitif kontrol: bu kanallarda izin YOKSA güncelleme sessizce kurulamaz — indirme biter,
    # kurulum ekranı hiç açılmaz ve kullanıcı "güncellenmedi" der. Sessiz ölümü burada kırıyoruz.
    echo "  IHLAL [$kanal]: $KURULUM_IZNI YOK — indirilen APK kurulamaz." >&2
    echo "         Kaynak: apps/mobile/android/app/src/$kanal/AndroidManifest.xml" >&2
    violations=$((violations + 1))
  fi

  # ⚠️ AŞAĞIDAKİ İKİ DENETİM 2026-08-17'DE DÖNGÜNÜN İÇİNE ALINDI.
  #
  # Öncesinde döngünün DIŞINDAydılar ve `$MANIFEST` değişkeninin son turdan SIZAN değerini
  # okuyorlardı: üç kanal üretilmiş olsa bile yalnız SONUNCUSU (sıralamada `sahaRelease`)
  # sınanıyordu. `magaza` APK'sından CallScreeningService ya da READ_CONTACTS düşse denetim
  # bunu GÖRMEZDİ — ve arayan tanıma tam olarak mağaza sürümünde sessizce ölürdü. Betiğin
  # kendi yorumu "HEPSİ denetlenir, ilki değil" diyordu; bu iki denetim için doğru değildi.
  #
  # Ayrıca eski yerleri `violations > 0` çıkışının ALTINDAydı: bir izin ihlali varken bu iki
  # eksik hiç raporlanmıyordu. Artık ikisi de aynı sayaca yazıyor, tek koşuda tam liste çıkıyor.

  # CallScreeningService gerçekten beyan edilmiş mi? Kaldırılırsa arayan tanıma sessizce ölür.
  if ! grep -q "android.telecom.CallScreeningService" "$MANIFEST"; then
    echo "  IHLAL [$kanal]: CallScreeningService beyanı yok — arayan tanıma çalışmaz." >&2
    violations=$((violations + 1))
  fi

  # READ_CONTACTS zorunlu. Telecom'un CallScreeningServiceFilter'ı, bu izne sahip olmayan
  # tarama uygulamasını rehberde KAYITLI numaralardan gelen çağrılarda hiç uyandırmaz:
  #     if (priorStageResult.contactExists && !hasReadContactsPermission()) { atla }
  # İzin manifest'ten düşerse hata sessizdir: uygulama çalışır, testler geçer, ama bayinin
  # rehberine kaydettiği (yani en sık aradığı) müşterilerde kart çıkmaz. Gerçek cihazda
  # doğrulandı: izinle birlikte "contact exists" olan çağrıda da SCREENING_BOUND alınıyor.
  if ! grep -q "uses-permission[^>]*\"android.permission.READ_CONTACTS\"" "$MANIFEST"; then
    echo "  IHLAL [$kanal]: READ_CONTACTS beyanı yok." >&2
    echo "         Rehberde kayıtlı müşteriler aradığında arayan tanıma SESSİZCE çalışmaz." >&2
    violations=$((violations + 1))
  fi
done

if [[ $violations -gt 0 ]]; then
  echo "" >&2
  echo "$violations sorun bulundu (birleştirilmiş manifest). Kırmızı çizgi #6 ihlal ediliyor." >&2
  echo "Kaynağı bulmak için:  cd apps/mobile/android && ./gradlew :app:processDebugMainManifest --info" >&2
  echo "Yasaklı izin için: ilgili izni AndroidManifest.xml'e tools:node=\"remove\" ile ekleyin." >&2
  exit 1
fi

echo "Temiz (${#MANIFESTLER[@]} kanal): yasaklı izin yok, CallScreeningService ve READ_CONTACTS yerinde."
