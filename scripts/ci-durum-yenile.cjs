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
try {
  const govde = calistir(
    'curl',
    [
      '-s', '-L', '--max-time', '8',
      `https://github.com/tnyligokhan/sipario/releases/download/saha/surum.json?t=${Date.now()}`,
    ],
    10000,
  );
  const j = JSON.parse(govde);
  if (typeof j.yapim === 'number') sonuc.yayindakiYapim = j.yapim;
  // SemVer de alınır: çubuk artık ÖNCE sürümü gösteriyor (kullanıcı isteği 2026-08-09 —
  // "derleme numarası kafa karıştırıyor, kaçta kalmıştım anlamıyorum"). Yapım numarası
  // yalnız "yayınlanmamış değişiklik var mı" sorusunu cevaplamak için saklanıyor.
  if (typeof j.surum === 'string') sonuc.yayindakiSurum = j.surum;
} catch (_) {}

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

try {
  fs.writeFileSync(hedef, JSON.stringify(sonuc));
} catch (_) {}
