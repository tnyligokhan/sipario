#!/usr/bin/env node
/**
 * CI durumu ÖNBELLEĞİNİ tazeler — durum çubuğu bunu ASLA kendisi yapmaz.
 *
 * NEDEN AYRI SÜREÇ: `statusline.cjs` her çizimde koşar (saniyede birden fazla olabilir) ve
 * içinde ağ çağrısı barındıramaz — `gh` ~1 sn, `curl` ~0,4 sn sürer; durum çubuğu o süre
 * boyunca donar ya da hiç görünmez. Bu betik ARKA PLANDA, kopuk (detached) olarak koşar,
 * sonucu tek satırlık bir dosyaya yazar; çubuk yalnız o dosyayı okur (mikrosaniye).
 *
 * Yazılan dosya: .claude/ci-durum.json (gitignore'da — makineye özgü, anlık durum).
 *
 * HER HATA SESSİZDİR: CI durumu bir kolaylıktır. `gh` kurulu değilse, ağ yoksa ya da depo
 * uzaktan kopuksa çubuk o segmenti hiç göstermez — hata basmaz (statusline disiplininin aynısı).
 */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const dir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const hedef = path.join(dir, '.claude', 'ci-durum.json');

function calistir(cmd, args, ms) {
  return execFileSync(cmd, args, {
    cwd: dir,
    encoding: 'utf8',
    timeout: ms,
    stdio: ['ignore', 'pipe', 'ignore'],
    windowsHide: true,
  }).trim();
}

const sonuc = { ts: Date.now() };

// 1) Son koşum (mobil-apk: telefona giden APK'yı üreten hat budur).
//    ⚠️ Dosya adı 2026-08-09'da `saha-apk.yml` → `mobil-apk.yml` oldu (hat iki kanallı hâle
//    geldi). Eski ad burada güncellenmeseydi `gh` sessizce boş dönerdi ve çubuk CI durumunu
//    HİÇ göstermezdi — hata basmaz, yalnız kaybolurdu. Bu betiğin "her hata sessizdir"
//    disiplini, yanlış bir adı da sessizce yutar; o yüzden ad değişimi buraya taşınmalıdır.
try {
  const ham = calistir(
    'gh',
    ['run', 'list', '--workflow', 'mobil-apk.yml', '--limit', '1', '--json', 'status,conclusion'],
    8000,
  );
  const [k] = JSON.parse(ham);
  if (k) sonuc.kosum = k.status === 'completed' ? k.conclusion : k.status;
} catch (_) {}

// 2) Yayındaki yapım numarası. SORGU PARAMETRESİ ŞART: düz adres GitHub CDN'inden saatlerce
//    bayat cevap dönebiliyor (2026-07-29'da ölçüldü) ve çubuk "telefon eski" derken aslında
//    güncel olurdu — yanlış bilgi, bilgisizlikten kötüdür.
// İKİ KANAL birden okunur (2026-08-09): `saha` bayilerin telefonunu, `test` geliştirme
// ekibinin cihazını temsil eder. Tek kanala bakmak "kim neyi görüyor?" sorusunu yarım
// bırakıyordu — ki bu projede o yarım cevap gerçek bir arızayı gizlemişti (dev'e atılan
// her push sahaya iniyordu ve kimse fark etmiyordu).
for (const kanal of ['saha', 'test']) {
  try {
    const govde = calistir(
      'curl',
      [
        '-s', '-L', '--max-time', '8',
        `https://github.com/tnyligokhan/sipario/releases/download/${kanal}/surum.json?t=${Date.now()}`,
      ],
      10000,
    );
    const j = JSON.parse(govde);
    const kutu = {};
    if (typeof j.yapim === 'number') kutu.yapim = j.yapim;
    if (typeof j.surum === 'string') kutu.surum = j.surum;

    // BEKLEYEN = yayınlanmamış MOBİL değişiklik sayısı (belge/sunucu commit'leri SAYILMAZ).
    //
    // ⚠️ NEDEN HAM COMMIT FARKI DEĞİL: `yapim` git commit sayacıdır ve HER commit'te artar;
    // oysa mobil derleme yalnız `apps/mobile/**` değiştiğinde tetiklenir (iş akışının `paths`
    // süzgeci). Bir belge commit'i sayacı artırıp derlemeyi tetiklemediği için ortaya HİÇBİR
    // YAPIMIN KAPATAMAYACAĞI hayalet bir "+1" çıkıyordu — ölçüldü ve düzeltmenin sebebi bu.
    // SHA varsa kesin hesaplanır; yoksa (eski release) ham farka düşülür.
    if (typeof j.commit === 'string' && /^[0-9a-f]{7,40}$/.test(j.commit)) {
      try {
        calistir('git', ['cat-file', '-e', `${j.commit}^{commit}`], 5000);
        kutu.bekleyen = parseInt(
          calistir('git', ['rev-list', '--count', `${j.commit}..HEAD`, '--', 'apps/mobile'], 5000),
          10,
        );
      } catch (_) {
        // SHA yerelde yok (fetch edilmemiş) — sessizce hesaplama yapılmaz, çubuk ham farka düşer.
      }
    }
    if (Object.keys(kutu).length) sonuc[kanal] = kutu;
  } catch (_) {}
}

// 3) Yerel commit sayısı = bu ağacın üreteceği yapım numarası (gradle aynı sayacı kullanır).
try {
  sonuc.yerelYapim = parseInt(calistir('git', ['rev-list', '--count', 'HEAD'], 5000), 10);
} catch (_) {}

// 4) YEREL SÜRÜMLER — iki ayrı hat (SemVer kuralı: CLAUDE.md → "Sürümleme").
//    Dosyadan OKUNUR, git'ten türetilmez: sürüm insan kararıdır, commit sayısı değil.
try {
  const p = fs.readFileSync(path.join(dir, 'apps', 'mobile', 'pubspec.yaml'), 'utf8');
  const m = p.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)/m);
  if (m) sonuc.yerelSurum = m[1];
} catch (_) {}

try {
  const c = fs.readFileSync(path.join(dir, 'apps', 'api', 'config', 'app.php'), 'utf8');
  const m = c.match(/'version'\s*=>\s*'([^']+)'/);
  if (m) sonuc.apiSurum = m[1];
} catch (_) {}

// 4b) CANLIDAKİ API sürümü — dosyadan değil SUNUCUDAN okunur (`GET /api/v1/version`, kimliksiz).
//
// NEDEN AYRI BİR ÖLÇÜM: yukarıdaki satır AĞACIN sürümünü söyler, yani "bu depoda ne yazıyor".
// Sunucuda o an KOŞAN sürüm bambaşka olabilir — deploy edilmemiş, deploy düşmüş ya da `main`
// geride. Bu depoda o fark ölçüldü ve zararı görüldü: 2026-08-09'da `main`, `dev`'in 41 commit
// gerisindeydi ve sunucu ile telefonlar farklı kod çalıştırıyordu. Bir sürüm numarası ancak
// KOŞAN kodu gösterdiğinde soruya cevap verir.
//
// Uç noktanın kimliksiz olmasının sebebi tam da budur: burada token yoktur.
try {
  const govde = calistir(
    'curl',
    ['-s', '-L', '--max-time', '6', `https://api.sipario.com.tr/api/v1/version?t=${Date.now()}`],
    8000,
  );
  const j = JSON.parse(govde);
  if (typeof j.api_version === 'string' && j.api_version) sonuc.apiCanli = j.api_version;
} catch (_) {}

// 5) YAYIN BORCU: `dev`de olup `main`e geçmemiş commit sayısı = bayilere ULAŞMAMIŞ iş.
//    Bu sayı bu projede soyut değil: 2026-08-09'da 41'e çıkmıştı ve sunucu (main) ile
//    telefonlar (dev'den derleniyordu) farklı kod çalıştırıyordu. Çubukta durması,
//    o farkın bir daha sessizce büyümemesi içindir.
//
//    ⚠️ UZAK DALLAR ESAS, YERELİ YEDEK (2026-08-10'da ölçülerek düzeltildi). Eskiden burada
//    düz `main..dev` yazıyordu ve çubuk **YAYIN BORCU 384** diyordu — gerçek borç **0**'dı.
//    Sebep: kimse yerelde `main`e checkout etmiyor, oturum başındaki fast-forward yalnız
//    çalışılan dalı ilerletiyor, yani yerel `main` ref'i aylarca donuyor (ölçüm: yerel
//    `16833e7`, uzak `827767a`). CI ise dalları UZAKTAN okur; "bayilere ulaşmamış iş" sorusunun
//    doğru cevabı orada.
//    Bu, çubuğun var oluş sebebinin ta kendisine düşen bir kusurdu: 41'i görünce alarm veren
//    bir gösterge, 0 iken 384 diyorsa artık okunmaz — kırmızı sayı gürültüye dönüşür ve gerçek
//    borç büyüdüğünde kimse fark etmez. Yanlış alarmın bedeli bu depoda `running:unhealthy`
//    ile bir kez ödendi.
try {
  let n = NaN;
  try {
    n = parseInt(calistir('git', ['rev-list', '--count', 'origin/main..origin/dev'], 5000), 10);
  } catch (_) {
    // Uzak ref yoksa (taze klon, fetch edilmemiş) yerel dallara düşülür — yanlış olabilir ama
    // hiç göstermemekten iyidir; sessizce kaybolan bir sayı da bu betiğin bilinen tuzağıdır.
    n = parseInt(calistir('git', ['rev-list', '--count', 'main..dev'], 5000), 10);
  }
  if (Number.isFinite(n)) sonuc.yayinBorcu = n;
} catch (_) {}

// 6) Hangi daldayız — çubuk "ağaç" satırını buna göre etiketler.
try {
  sonuc.dal = calistir('git', ['rev-parse', '--abbrev-ref', 'HEAD'], 5000);
} catch (_) {}

try {
  fs.writeFileSync(hedef, JSON.stringify(sonuc));
} catch (_) {}
