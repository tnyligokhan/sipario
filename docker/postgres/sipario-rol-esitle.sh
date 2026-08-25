#!/bin/bash
# Sunucu ayağa kalkar kalkmaz rol parolalarını env ile hizalar.
#
# NEDEN CONTAINER'IN İÇİNDE: hizalamayı dışarıdan yapmak imkânsızdır. Owner parolası
# bayatladığında dışarıdaki hiçbir istemci kimlik doğrulayamaz — düzeltmek için gereken
# yetkiye ancak parola sorulmayan yoldan ulaşılır. pg_hba.conf'taki `local all all trust`
# tam olarak bu yoldur ve yalnız container'ın içinden geçilir.
#
# NEDEN ARKA PLANDA: postgres'in kendi entrypoint'i ön planda koşmak zorundadır (PID 1).
# Bu betik onun yanında koşar, işini bitirir ve çıkar; postgres'i ASLA öldürmez —
# yarım hizalanmış bir veritabanı, hiç açılmayan bir veritabanından iyidir ve
# başarısızlık aşağıda yüksek sesle günlüğe düşer.
set -uo pipefail

ISARET="[SIPARIO-ROL-ESITLEME]"
ROL_BETIGI=/docker-entrypoint-initdb.d/10-roles.sh

# İlk turlar initdb'nin GEÇİCİ sunucusuna denk gelebilir; o aşamada veritabanı henüz
# yaratılmamış olabilir ve betik haklı olarak düşer. Bu yüzden tek denemeyle hüküm
# verilmez: gerçek sunucu ayağa kalkana kadar yeniden denenir.
for deneme in $(seq 1 30); do
  if pg_isready -q -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" 2>/dev/null; then
    if "$ROL_BETIGI" >/dev/null 2>&1; then
      echo "$ISARET roller env parolalariyla hizalandi (deneme $deneme)" >&2
      exit 0
    fi
  fi
  sleep 2
done

# Buraya düşmek, uygulamanın birazdan "password authentication failed" ile çökeceği
# anlamına gelir. Sebebi arayan kişi bu satırı görsün diye çıktı bilerek gürültülüdür.
echo "$ISARET BASARISIZ — roller hizalanamadi. Uygulama parola dogrulamasinda cokecek." >&2
"$ROL_BETIGI" >&2 || true
exit 1
