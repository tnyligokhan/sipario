#!/usr/bin/env node
/**
 * Sipario status line — PLAN.md "İlerleme panosu"ndan Genel% + mevcut Faz% okur, en başa koyar;
 * ardından (varsa) ruflo'nun kendi statusline'ını best-effort ekler (çıktısı korunur).
 * Her adımda try/catch — statusline ASLA hata basmaz, sessizce boş geçer.
 */
const fs = require('fs');
const path = require('path');

const dir = process.env.CLAUDE_PROJECT_DIR || process.cwd();

// ── RENK ─────────────────────────────────────────────────────────────────────────────────
// Yalnız TEMEL ANSI kodları (30-37/90-97): 256 renk ve truecolor her terminalde aynı
// görünmez, çubuk da her terminalde okunmak zorunda. `NO_COLOR` standardına uyulur —
// renkleri kapatan kullanıcıya rağmen kod basmak, çubuğu okunmaz karakter çöplüğüne çevirir.
//
// ETİKET GRİ, DEĞER PARLAK: göz önce değeri bulsun. Etiket bağlam verir ama okunması
// gereken şey sayıdır; ikisi aynı parlaklıkta olursa satır tek bir gri blok gibi görünür
// (önceki hâlin okunmama sebebi buydu).
const renkVar = !process.env.NO_COLOR;
const b = (kod, s) => (renkVar ? `\x1b[${kod}m${s}\x1b[0m` : String(s));
const etiket = (s) => b('90', s);        // gri — bağlam
const deger = (s) => b('1;97', s);       // parlak beyaz + kalın — okunacak şey
const uyari = (s) => b('1;33', s);       // sarı — bekleyen iş
const iyi = (s) => b('1;32', s);         // yeşil — hizada
const kotu = (s) => b('1;31', s);        // kırmızı — dikkat
const ayrac = etiket('│');

// Claude Code oturum JSON'ını stdin'den verir; ruflo'ya aynen iletmek için yakala.
let input = '';
try {
  input = fs.readFileSync(0, 'utf8');
} catch (_) {
  input = '';
}

/**
 * PLAN.md panosundan ilerleme segmenti.
 *
 * ETİKETLER BÜYÜK HARF — çubuğun tamamında tek bir yazım düzeni var (GENEL · FAZ · CI ·
 * SAHA · TEST · API · AĞAÇ · YAYIN BORCU). Karışık yazım, gözün satırı "tarayacağı" yerine
 * "okumasına" yol açar ve çubuk bir bakışta anlaşılmaz hâle gelir.
 */
function progressSegment() {
  try {
    const plan = fs.readFileSync(path.join(dir, 'PLAN.md'), 'utf8');
    const full = plan.match(/Genel proje:\s*~?%\s*(\d+)[\s\S]*?Faz\s*(\d+)[\s\S]*?~?%\s*(\d+)/);
    // `~` KORUNUR: PLAN.md'deki yüzdeler EFOR TAHMİNİDİR, ölçüm değil. Tildeyi atmak
    // sayıya sahip olmadığı bir kesinlik verirdi.
    if (full) {
      return `${etiket('GENEL')} ${deger('~%' + full[1])}  ${ayrac}  ${etiket('FAZ ' + full[2])} ${deger('~%' + full[3])}`;
    }
    const gen = plan.match(/Genel proje:\s*~?%\s*(\d+)/);
    if (gen) return `${etiket('GENEL')} ${deger('~%' + gen[1])}`;
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
 * SÜRÜM SATIRI — "kim neyi görüyor?" sorusunun tek bakışta cevabı.
 *
 * TASARIM GEREKÇESİ (kullanıcı isteği 2026-08-09): eski rozet `📱 383` gibi bir GİT COMMIT
 * SAYISI gösteriyordu. O sayı hiçbir insan sorusunu cevaplamıyor — "kaçta kalmıştım, ne
 * olmuştu?" diye bakan biri için anlamsız. Yeni satır üç ayrı izleyicinin gördüğü sürümü
 * yan yana koyar; sayılar yalnız BEKLEYEN İŞ varken ve "+N" biçiminde görünür.
 *
 *   saha 0.9.0 · test 0.10.0 +2 · ağaç 0.10.0 · api 1.0.0 · yayın borcu 41
 *   └ bayiler    └ ekip           └ bu ağaç     └ sunucu    └ dev'de olup main'e geçmemiş
 *
 * Her parça FARKLI bir soruyu cevaplar ve hiçbiri diğerinin yerine geçmez:
 *   saha        → bayinin telefonunda ne var? (yalnız `main` besler)
 *   test        → ekibin cihazında ne var? (yalnız `dev` besler)
 *   +N          → ağaç o kanaldan N commit ileride, yani işim henüz YAYINLANMADI
 *   ağaç        → yalnız kanallarla AYRIŞTIĞINDA çizilir (aynıysa gürültüdür)
 *   api         → sunucu sözleşmesinin sürümü; mobile EŞİTLENMEZ (CLAUDE.md → Sürümleme)
 *   yayın borcu → bayilere ulaşmamış iş. 2026-08-09'da 41'e çıkmıştı ve sunucu ile
 *                 telefonlar farklı kod çalıştırıyordu; sayı bu yüzden görünür duruyor.
 *
 * SESSİZLİK KURALI: bir bilgi alınamadıysa o parça HİÇ çizilmez (uydurma değer yok);
 * sürümler tamamen alınamadıysa eski yapım-numarası davranışına düşülür — bilgi
 * vermemektense ham sayı vermek yeğdir.
 */
function surumSatiri(veri) {
  const p = [];
  const yerelS = veri.yerelSurum;
  const yerelY = veri.yerelYapim;

  const kanal = (ad, k) => {
    if (!k) return null;
    if (!k.surum) return k.yapim != null ? `${etiket(ad)} ${deger(k.yapim)}` : null;
    // BEKLEYEN yayınlanmamış MOBİL değişiklik sayısıdır — belge/sunucu commit'leri sayılmaz.
    // Yoksa (eski release, SHA yayınlamıyor) ham commit farkına düşülür; o sayı bir belge
    // commit'inde de artar ve hiçbir yapımın kapatamadığı hayalet bir "+1" üretir, bu yüzden
    // yalnız YEDEKTİR.
    const fark =
      k.bekleyen != null
        ? k.bekleyen
        : k.yapim != null && yerelY != null
          ? yerelY - k.yapim
          : 0;
    // Hizadaysa YEŞİL onay: "bekleyen iş yok" bilgisi, sarı bir sayının yokluğundan
    // okunmamalı — yokluk fark edilmez, işaret edilir.
    const son = fark > 0 ? uyari(`+${fark}`) : iyi('✓');
    return `${etiket(ad)} ${deger(k.surum)} ${son}`;
  };

  const saha = kanal('SAHA', veri.saha);
  const test = kanal('TEST', veri.test);
  if (saha) p.push(saha);
  if (test) p.push(test);

  // Hiç kanal okunamadıysa eski davranış: ham yapım numarası.
  if (!saha && !test && yerelY != null) p.push(`${etiket('YAPIM')} ${deger(yerelY)}`);

  // "AĞAÇ" YALNIZ ayrıştığında: iki kanaldan biriyle bile aynıysa satırı şişirmez.
  const kanalSurumleri = [veri.saha?.surum, veri.test?.surum].filter(Boolean);
  if (yerelS && kanalSurumleri.length && !kanalSurumleri.includes(yerelS)) {
    p.push(`${etiket('AĞAÇ')} ${uyari(yerelS)}`);
  }

  // API: CANLIDA KOŞAN sürüm esastır, ağaçtaki değil — soru "sunucu hangi sözleşmeyi konuşuyor".
  // İkisi ayrıştığında ok işaretiyle ikisi birden yazılır (`API 1.0.0→1.0.1`): sol taraf canlı,
  // sağ taraf ağaç, yani "sunucuya gitmemiş sürüm artışı". Aynıysa tek numara yeter.
  // Canlı okunamazsa (ağ yok, sunucu düştü) sessizce ağaçtaki değere düşülür — çubuk hata basmaz.
  if (veri.apiCanli && veri.apiSurum && veri.apiCanli !== veri.apiSurum) {
    p.push(`${etiket('API')} ${deger(veri.apiCanli)}${uyari(`→${veri.apiSurum}`)}`);
  } else if (veri.apiCanli || veri.apiSurum) {
    p.push(`${etiket('API')} ${deger(veri.apiCanli || veri.apiSurum)}`);
  }
  // Yayın borcu bir BORÇTUR: sıfırsa hiç yazılmaz, büyüdükçe rengi sertleşir.
  // 20 eşiği keyfi değil — 2026-08-09'da borç 41'e çıktığında sunucu ile telefonlar
  // farklı kod çalıştırıyordu; o noktaya varmadan gözün takılması gerekiyor.
  if (veri.yayinBorcu > 0) {
    const n = veri.yayinBorcu;
    p.push(`${etiket('YAYIN BORCU')} ${n >= 20 ? kotu(n) : uyari(n)}`);
  }
  return p.join(`  ${ayrac}  `);
}

function ciVeri() {
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

    return veri;
  } catch (_) {}
  return null;
}

/**
 * CI rozeti — emoji DEĞİL, renkli metin.
 *
 * Emoji terminalden terminale farklı genişlikte çizilir ve hizalamayı bozar; ayrıca renk
 * körlüğünde 🟢/🔴 ayrımı yalnız RENGE dayanır. Metin + renk ikisini birden verir:
 * işaret şekli (✓ ✗ ●) renksiz de okunur.
 */
function ciRozeti(veri) {
  if (!veri) return '';
  const harita = {
    success: iyi('✓'),
    failure: kotu('✗'),
    in_progress: uyari('●'),
    queued: uyari('●'),
  };
  const isaret = harita[veri.kosum];
  return isaret ? `${etiket('CI')} ${isaret}` : '';
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

// İKİ SATIR (kullanıcı isteği 2026-08-09: "yan yana olmak zorunda değil").
//
// ÜST SATIR = DURUM: ilerleme · CI · ruflo. Sık değişir, göz buraya alışıktır.
// ALT SATIR = SÜRÜMLER: kim neyi görüyor. Seyrek değişir ama en çok merak edilen bilgidir;
// üst satıra sıkıştırılsaydı `|` ile ayrılmış uzun bir dizide kaybolurdu.
//
// Sürüm satırı boşsa (önbellek yok / ağ yok) HİÇ yazılmaz — boş bir satır bırakmak, çubuğu
// bir satır büyütüp hiçbir bilgi vermemek olurdu.
const veri = ciVeri();
const ust = [progressSegment(), ciRozeti(veri), rufloSegment()]
  .filter(Boolean)
  .join(`  ${ayrac}  `);
const alt = veri ? surumSatiri(veri) : '';
process.stdout.write([ust, alt].filter(Boolean).join('\n'));
