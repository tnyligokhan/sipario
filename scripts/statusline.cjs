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

const parts = [progressSegment(), rufloSegment()].filter(Boolean);
process.stdout.write(parts.join('  |  '));
