#!/usr/bin/env bash
# CI — YEREL VARLIK (native asset) İNDİRMESİ DÜŞERSE YENİDEN DENE, TEST HATASINDA ASLA.
#
# NEDEN VAR: `sqlite3` paketi derleme kancasında GitHub Releases'ten hazır bir kütüphane indirir
# (`libsqlite3.<abi>.<os>.so`). İndirme her `flutter test` / `flutter build` koşumunda yapılır ve
# ağ arızasında iş kırmızı olur:
#
#   By default, this package downloads a pre-compiled SQLite library.
#   This failed (attepted to download https://github.com/simolus3/sqlite3.dart/releases/...)
#   Original cause: HttpException: Connection closed before full header was received
#
# Bu hata KODLA İLGİLİ DEĞİLDİR. Ölçüldü (2026-08-13): mobil testler yeşilken iş yalnız bu
# yüzden kırmızıya döndü ve APK yayınlanmadı.
#
# NEDEN `user_defines: {sqlite3: {source: system}}` DEĞİL: o ayar `pubspec.yaml`ta yaşar ve TÜM
# hedeflere uygulanır. Linux'ta sistemdeki kütüphaneye geçmek CI'ı kurtarırdı ama aynı ayar
# ANDROID derlemesine de iner; telefonda paketlenmiş kütüphane yerine cihazdan `libsqlite3.so`
# aranır. Yani sunucudaki bir ağ arızasını, bayinin telefonunda veri katmanının açılmama riskiyle
# takas etmek olurdu. Ayar hedef bazında verilemiyor (kancanın `description.dart`ı yalnız
# kütüphane ADINI hedefe göre okuyor, KAYNAĞINI değil).
#
# KURAL — YALNIZ AĞ ŞEKİLLİ ARIZA TEKRARLANIR: gerçek bir test/derleme hatası ilk turda,
# olduğu gibi, kendi çıkış koduyla dışarı verilir. Kırmızıyı üç kez deneyip yeşile zorlamak
# bekçiyi işe yaramaz hâle getirirdi.
#
# Kullanım: scripts/ci-varlik-indirmesini-yeniden-dene.sh flutter test

set -uo pipefail

if [ "$#" -eq 0 ]; then
  echo "kullanım: $0 <komut> [argümanlar…]" >&2
  exit 64
fi

# Ağ şekilli arızanın imzaları. Derleyici hatası ("undefined reference") bu desenlerin
# hiçbirine uymaz ve tekrarlanmaz.
AG_DESENI='downloads a pre-compiled SQLite library|Connection closed before full header|Failed host lookup|HandshakeException|Connection timed out|SocketException|502 Bad Gateway|503 Service Unavailable'

AZAMI_DENEME=3

for deneme in $(seq 1 "$AZAMI_DENEME"); do
  gunluk="$(mktemp)"
  "$@" 2>&1 | tee "$gunluk"
  kod="${PIPESTATUS[0]}"

  if [ "$kod" -eq 0 ]; then
    rm -f "$gunluk"
    exit 0
  fi

  if ! grep -qE "$AG_DESENI" "$gunluk"; then
    # Gerçek hata: sebebi kod. Tekrar YOK.
    rm -f "$gunluk"
    exit "$kod"
  fi

  rm -f "$gunluk"
  if [ "$deneme" -lt "$AZAMI_DENEME" ]; then
    bekle=$((deneme * 15))
    echo "::warning::Yerel varlık indirmesi ağ hatasıyla düştü ($deneme/$AZAMI_DENEME) — ${bekle}sn sonra yeniden denenecek."
    sleep "$bekle"
  fi
done

echo "::error::Yerel varlık indirmesi $AZAMI_DENEME denemede de düştü. Kod hatası değil; GitHub Releases'e erişilemiyor."
exit 1
