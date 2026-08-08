#!/usr/bin/env node

/**
 * Sipario CI/CD ve Saha APK Derleme Durum Kontrol Paneli
 *
 * Kullanım:
 *   .\ci.bat
 *   .\ci.bat -t       (Canlı Takip / Watch)
 *   .\ci.bat -w       (Tarayıcıda Aç)
 */

const { execSync } = require('child_process');
const https = require('https');

const args = process.argv.slice(2);
const isWatch = args.includes('-t') || args.includes('--takip') || args.includes('-w') || args.includes('--watch');
const isOpen = args.includes('-o') || args.includes('--open') || args.includes('--web');

// ANSI Renk Kodları
const C = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  cyan: '\x1b[36m',
  yellow: '\x1b[33m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  white: '\x1b[37m',
  bgBlue: '\x1b[44m',
  bgYellow: '\x1b[43m',
  bgGreen: '\x1b[42m',
  bgRed: '\x1b[41m',
  black: '\x1b[30m',
};

function clearScreen() {
  process.stdout.write('\x1b[2J\x1b[0;0H');
}

function getCIData() {
  try {
    const raw = execSync(
      'gh run list --limit 6 --json databaseId,name,headBranch,status,conclusion,event,createdAt,updatedAt,headSha,displayTitle',
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], windowsHide: true }
    );
    return JSON.parse(raw);
  } catch (e) {
    return null;
  }
}

function getJobs(runId) {
  try {
    const raw = execSync(
      `gh run view ${runId} --json jobs`,
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], windowsHide: true }
    );
    const parsed = JSON.parse(raw);
    return parsed.jobs || [];
  } catch (e) {
    return [];
  }
}

async function getReleaseInfo() {
  return new Promise((resolve) => {
    const ts = Date.now();
    const url = `https://github.com/tnyligokhan/sipario/releases/download/saha/surum.json?t=${ts}`;
    const req = https.get(url, { headers: { 'User-Agent': 'Sipario-CLI' } }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        https.get(res.headers.location, { headers: { 'User-Agent': 'Sipario-CLI' } }, (redRes) => {
          let data = '';
          redRes.on('data', (c) => (data += c));
          redRes.on('end', () => {
            try { resolve(JSON.parse(data)); } catch (e) { resolve(null); }
          });
        }).on('error', () => resolve(null));
        return;
      }
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch (e) { resolve(null); }
      });
    });
    req.on('error', () => resolve(null));
    req.setTimeout(4000, () => { req.destroy(); resolve(null); });
  });
}

async function render() {
  clearScreen();
  const now = new Date().toLocaleTimeString('tr-TR');

  console.log(`${C.cyan}════════════════════════════════════════════════════════════════════════${C.reset}`);
  console.log(`${C.bgBlue}${C.white}${C.bold}  🚀 SIPARIO CI/CD & SAHA APK KONTROL PANELİ                           ${C.reset}`);
  console.log(`${C.cyan}════════════════════════════════════════════════════════════════════════${C.reset}`);
  console.log(`${C.dim}  Zaman: ${now}${C.reset}\n`);

  const runs = getCIData();
  const release = await getReleaseInfo();

  if (!runs || runs.length === 0) {
    console.log(`${C.red}  ❌ GitHub Actions verisi alınamadı! (gh CLI yetkisi kontrol edilmeli)${C.reset}`);
    return false;
  }

  const sahaRun = runs.find((r) => r.name === 'saha-apk');

  // 1. SAHA APK DURUMU
  console.log(`${C.yellow}${C.bold}📱 SAHA APK (MOBİL İŞ AKIŞI)${C.reset}`);
  console.log(`${C.dim}────────────────────────────────────────────────────────────────────────${C.reset}`);

  if (sahaRun) {
    let badge = '';
    if (sahaRun.status === 'in_progress') {
      badge = `${C.bgYellow}${C.black}${C.bold} 🟡 DERLENİYOR (In Progress) ${C.reset}`;
    } else if (sahaRun.status === 'queued') {
      badge = `${C.bgYellow}${C.black}${C.bold} ⏳ SIRADA (Queued) ${C.reset}`;
    } else if (sahaRun.conclusion === 'success') {
      badge = `${C.bgGreen}${C.black}${C.bold} ✅ BAŞARILI (APK Yayında) ${C.reset}`;
    } else if (sahaRun.conclusion === 'failure') {
      badge = `${C.bgRed}${C.white}${C.bold} ❌ BAŞARISIZ (Hata Alındı) ${C.reset}`;
    } else {
      badge = `${C.dim}${sahaRun.status} (${sahaRun.conclusion})${C.reset}`;
    }

    console.log(`  Durum        : ${badge}`);
    console.log(`  Son Commit   : ${C.white}${sahaRun.displayTitle}${C.reset}`);
    console.log(`  Dal (Branch) : ${C.cyan}${sahaRun.headBranch}${C.reset}`);
    console.log(`  Koşum ID     : ${C.dim}${sahaRun.databaseId}${C.reset}`);
    console.log(`  Detay URL    : ${C.blue}https://github.com/tnyligokhan/sipario/actions/runs/${sahaRun.databaseId}${C.reset}`);

    if (sahaRun.status === 'in_progress' || sahaRun.conclusion === 'failure') {
      const jobs = getJobs(sahaRun.databaseId);
      if (jobs.length > 0) {
        console.log(`\n  ${C.yellow}Alt Görevler:${C.reset}`);
        for (const j of jobs) {
          let jIcon = '⏳ Bekliyor';
          if (j.status === 'in_progress') jIcon = `${C.yellow}🟡 Çalışıyor${C.reset}`;
          else if (j.conclusion === 'success') jIcon = `${C.green}✅ Tamamlandı${C.reset}`;
          else if (j.conclusion === 'failure') jIcon = `${C.red}❌ Hata${C.reset}`;
          console.log(`   • ${j.name.padEnd(28)} : ${jIcon}`);
        }
      }
    }
  } else {
    console.log(`  ${C.dim}saha-apk koşumu bulunamadı.${C.reset}`);
  }

  // 2. YAYINDAKİ SÜRÜM & APK
  console.log(`\n${C.yellow}${C.bold}📦 YAYINDAKİ SAHA SÜRÜMÜ (GitHub Releases)${C.reset}`);
  console.log(`${C.dim}────────────────────────────────────────────────────────────────────────${C.reset}`);

  if (release) {
    console.log(`  Sürüm Adı    : ${C.green}${C.bold}${release.ad || 'Saha'}${C.reset} (${release.kod || 'v1.0.0'})`);
    console.log(`  Yapım No     : ${C.white}Build #${release.yapim || '?'}${C.reset}`);
    console.log(`  Yayın Tarihi : ${C.cyan}${release.tarih || '-'}${C.reset}`);
    console.log(`  Release URL  : ${C.blue}https://github.com/tnyligokhan/sipario/releases/tag/saha${C.reset}`);
    console.log(`  Doğrudan APK : ${C.cyan}https://github.com/tnyligokhan/sipario/releases/download/saha/sipario-saha-arm64.apk${C.reset}`);
  } else {
    console.log(`  ${C.dim}Yayındaki sürüm bilgisine ulaşılamadı veya henüz release oluşmadı.${C.reset}`);
  }

  // 3. SON KOŞUMLAR LİSTESİ
  console.log(`\n${C.yellow}${C.bold}📋 SON İŞ AKIŞLARI${C.reset}`);
  console.log(`${C.dim}────────────────────────────────────────────────────────────────────────${C.reset}`);

  for (const r of runs.slice(0, 4)) {
    let icon = '⚪';
    if (r.status === 'in_progress') icon = '🟡';
    else if (r.conclusion === 'success') icon = '✅';
    else if (r.conclusion === 'failure') icon = '❌';

    const t = new Date(r.createdAt).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
    const name = r.name.padEnd(12);
    const branch = r.headBranch.padEnd(5);
    console.log(`  ${icon} [${t}] ${C.dim}${name} (${branch})${C.reset} : ${r.displayTitle}`);
  }

  console.log(`${C.cyan}════════════════════════════════════════════════════════════════════════${C.reset}\n`);

  if (isOpen && sahaRun) {
    try {
      execSync(`start https://github.com/tnyligokhan/sipario/actions/runs/${sahaRun.databaseId}`, { stdio: 'ignore' });
    } catch (e) {}
  }

  return sahaRun ? (sahaRun.status === 'in_progress' || sahaRun.status === 'queued') : false;
}

async function main() {
  if (isWatch) {
    while (true) {
      const isRunning = await render();
      if (isRunning) {
        console.log(`  ${C.yellow}⏳ Derleme devam ediyor... (4 sn sonra güncellenecek — Çıkış için Ctrl+C)${C.reset}`);
        await new Promise((r) => setTimeout(r, 4000));
      } else {
        console.log(`  ${C.green}${C.bold}🎉 Derleme tamamlandı!${C.reset}\n`);
        break;
      }
    }
  } else {
    await render();
    console.log(`  ${C.dim}İpucu: Canlı takip için \`ci -t\` veya \`.\\ci.bat -t\` çalıştırabilirsiniz.${C.reset}\n`);
  }
}

main();
