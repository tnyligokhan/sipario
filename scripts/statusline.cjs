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
/**
 * Telefon rozeti: YAYINDAKİ sürüm + (varsa) yayınlanmamış iş.
 *
 * Dört durum, dördü de tek bakışta ayrılabilir olmalı:
 *   📱 0.10.0        → yayındaki sürüm bu, ağaçta yayınlanmamış bir şey yok
 *   📱 0.10.0 +5     → aynı sürüm ama ağaçta 5 commit daha var (henüz telefonda değil)
 *   📱 0.9.0→0.10.0  → ağaçta SÜRÜM ARTMIŞ, telefon hâlâ eskisinde
 *   📱 0.10.0 ?      → sürüm okunamadı (surum.json bayat/erişilemez) — sessiz kalmaktansa soru işareti
 *
 * Sürüm bilgisi yoksa eski davranışa (yapım numarası) düşülür: bilgi vermemektense
 * ham sayı vermek yeğdir, ama varsayılan artık insan okunabilir sürümdür.
 */
function mobilRozeti(veri) {
  const yayin = veri.yayindakiSurum;
  const yerel = veri.yerelSurum;
  const fark =
    veri.yayindakiYapim != null && veri.yerelYapim != null
      ? veri.yerelYapim - veri.yayindakiYapim
      : null;

  if (!yayin) {
    // Sürüm alınamadı — yapım numarasıyla idare et (eski davranış).
    if (veri.yayindakiYapim == null || veri.yerelYapim == null) return '';
    return fark > 0 ? `📱 ${veri.yayindakiYapim}→${veri.yerelYapim}` : `📱 ${veri.yayindakiYapim}`;
  }
  if (yerel && yerel !== yayin) return `📱 ${yayin}→${yerel}`;
  if (fark != null && fark > 0) return `📱 ${yayin} +${fark}`;
  return `📱 ${yayin}`;
}

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
    // SÜRÜM ÖNCE, YAPIM NUMARASI YALNIZ GEREKTİĞİNDE (kullanıcı isteği 2026-08-09:
    // "derleme numarasına göre olunca kafam karışıyor, kaçta kalmıştım anlamıyorum").
    //
    // Neden yapım numarası tamamen atılmıyor: SemVer "değişikliğim telefona ULAŞTI MI?"
    // sorusunu TEK BAŞINA cevaplayamaz — aynı sürüm altında onlarca commit yayınlanır.
    // Bu yüzden sürüm insan için önde, yapım farkı ise yalnız YAYINLANMAMIŞ iş varken
    // ve "+N commit" biçiminde görünür. İkisi farklı soruları cevaplıyor.
    const mobil = mobilRozeti(veri);
    if (mobil) parcalar.push(mobil);
    // API hattı AYRIDIR ve uygulamaya eşitlenmez (CLAUDE.md → "Sürümleme").
    // ⚠️ Bu YEREL AĞACIN sürümü — canlıdaki API sürümü henüz hiçbir yanıtta yayınlanmıyor.
    // O açık borç kapandığında burası "yerel→canlı" farkını da gösterebilir.
    if (veri.apiSurum) parcalar.push(`🔌 ${veri.apiSurum}`);
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
