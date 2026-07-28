#!/usr/bin/env node
/**
 * Sipario status line — PLAN.md "İlerleme panosu"ndan Genel% + mevcut Faz% okur, en başa koyar;
 * ardından (varsa) ruflo'nun kendi statusline'ını best-effort ekler (çıktısı korunur).
 * Her adımda try/catch — statusline ASLA hata basmaz, sessizce boş geçer.
 */
const fs = require('fs');
const path = require('path');

const dir = process.env.CLAUDE_PROJECT_DIR || process.cwd();

// Claude Code oturum JSON'ını stdin'den verir; ruflo'ya aynen iletmek için yakala.
let input = '';
try {
  input = fs.readFileSync(0, 'utf8');
} catch (_) {
  input = '';
}

/** PLAN.md panosundan "Genel ~%NN · Faz N ~%MM" segmentini üret. */
function progressSegment() {
  try {
    const plan = fs.readFileSync(path.join(dir, 'PLAN.md'), 'utf8');
    const full = plan.match(/Genel proje:\s*~?%\s*(\d+)[\s\S]*?Faz\s*(\d+)[\s\S]*?~?%\s*(\d+)/);
    if (full) return `📊 Genel ~%${full[1]} · Faz ${full[2]} ~%${full[3]}`;
    const gen = plan.match(/Genel proje:\s*~?%\s*(\d+)/);
    if (gen) return `📊 Genel ~%${gen[1]}`;
  } catch (_) {}
  return '';
}

/**
 * CI segmenti — ÖNBELLEKTEN okur, ağa ÇIKMAZ.
 *
 * Durum çubuğu her çizimde koşar; içine `gh`/`curl` koymak onu saniyelerce dondururdu. Bu
 * yüzden ağ işini `ci-durum-yenile.cjs` KOPUK bir arka plan süreci olarak yapar ve buraya
 * yalnız hazır sonuç düşer. Önbellek bayatsa (60 sn) tazeleme TETİKLENİR ama BEKLENMEZ:
 * çubuk o an eski değeri gösterir, bir sonraki çizimde yenisi gelir.
 *
 * Kilit dosyası, tazelemenin üst üste binmesini engeller: ağ yavaşsa her çizimde yeni bir
 * süreç doğar ve makine `gh` süreçleriyle dolardı (saha sunucusu script'inde yetim süreçlerle
 * bir kez ödenen ders).
 */
function ciSegment() {
  try {
    const cache = path.join(dir, '.claude', 'ci-durum.json');
    const kilit = path.join(dir, '.claude', 'ci-durum.kilit');
    const simdi = Date.now();

    let veri = null;
    try {
      veri = JSON.parse(fs.readFileSync(cache, 'utf8'));
    } catch (_) {}

    const bayat = !veri || simdi - (veri.ts || 0) > 60_000;
    let kilitYasi = Infinity;
    try {
      kilitYasi = simdi - fs.statSync(kilit).mtimeMs;
    } catch (_) {}

    if (bayat && kilitYasi > 30_000) {
      try {
        fs.writeFileSync(kilit, String(simdi));
        const { spawn } = require('child_process');
        const cocuk = spawn(
          process.execPath,
          [path.join(dir, 'scripts', 'ci-durum-yenile.cjs')],
          { detached: true, stdio: 'ignore', windowsHide: true },
        );
        cocuk.unref();
      } catch (_) {}
    }

    if (!veri) return '';

    const isaret = { success: '🟢', in_progress: '🟡', queued: '🟡', failure: '🔴' }[veri.kosum];
    const parcalar = [];
    if (isaret) parcalar.push(`${isaret} CI`);
    // Telefonun göreceği yapım ile bu ağacın üreteceği yapım aynı mı? Asıl merak edilen soru
    // "CI yeşil mi" değil, "değişikliğim telefona ulaştı mı"dır.
    if (veri.yayindakiYapim != null && veri.yerelYapim != null) {
      parcalar.push(
        veri.yayindakiYapim >= veri.yerelYapim
          ? `📱 ${veri.yayindakiYapim}`
          : `📱 ${veri.yayindakiYapim}→${veri.yerelYapim}`,
      );
    }
    return parcalar.join(' ');
  } catch (_) {}
  return '';
}

/** ruflo'nun statusline'ını çocuk süreç olarak koştur, stdin'i ilet, stdout'u yakala. */
function rufloSegment() {
  try {
    const { execFileSync } = require('child_process');
    const home = process.env.USERPROFILE || process.env.HOME || '.';
    const candidates = [
      path.join(dir, '.claude', 'helpers', 'statusline.cjs'),
      path.join(home, '.claude', 'helpers', 'statusline.cjs'),
    ];
    const target = candidates.find((c) => fs.existsSync(c));
    if (!target) return '';
    const out = execFileSync(process.execPath, [target], {
      input,
      encoding: 'utf8',
      timeout: 3000,
      stdio: ['pipe', 'pipe', 'ignore'],
    });
    return (out || '').trim();
  } catch (_) {
    return '';
  }
}

const parts = [progressSegment(), ciSegment(), rufloSegment()].filter(Boolean);
process.stdout.write(parts.join('  |  '));
