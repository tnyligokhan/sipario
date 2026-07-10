# Sipario - kalite kapili otomatik commit (Claude Code Stop hook'u tarafindan calistirilir)
#
# Kurallar (pazarliksiz):
#  - Kapi KIRMIZI ise commit ATILMAZ; degisiklikler unstage edilip yerinde birakilir.
#  - main/master dalinda ASLA otomatik commit/push yapilmaz.
#  - Cikis kodu HER ZAMAN 0 (Stop hook'undan exit 2 = Claude'un durmasini engellemek; asla yapilmaz).
#  - Arac kurulu degilse o kontrol atlanir ama "atlandi" olarak commit govdesine yazilir -
#    calismamis kontrol basarili sayilmaz, yalnizca gorunur sekilde atlanir.
#  - Sonsuz dongu korumasi: stop_hook_active geldiyse hic calismadan cikilir.
#
# Not: Bu dosya sir taramasinin kendisinden HARIC tutulur (regex kaliplarini iceriyor).

$ErrorActionPreference = 'Continue'

function Emit([string]$msg) {
  @{ systemMessage = $msg } | ConvertTo-Json -Compress
}

# --- stdin + sonsuz dongu korumasi ---
$raw = ''
if ([Console]::IsInputRedirected) {
  try { $raw = [Console]::In.ReadToEnd() } catch { }
}
if ($raw) {
  try {
    $payload = $raw | ConvertFrom-Json
    if ($payload.stop_hook_active -eq $true) { exit 0 }
  } catch { }
}

# --- proje koku ---
$root = $env:CLAUDE_PROJECT_DIR
if (-not $root -or -not (Test-Path $root)) {
  $root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
Set-Location $root

git rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { exit 0 }

# --- dal korumasi ---
$branch = ''
try { $branch = (git branch --show-current 2>$null | Out-String).Trim() } catch { }
if (-not $branch) { exit 0 }                                  # detached HEAD
if ($branch -eq 'main' -or $branch -eq 'master') { exit 0 }   # korumali dallar

# --- degisiklik var mi ---
$dirty = git status --porcelain 2>$null
if (-not $dirty) { exit 0 }

git add -A 2>$null | Out-Null
$staged = @(git diff --cached --name-only 2>$null)
if ($staged.Count -eq 0) { exit 0 }

$failed  = New-Object System.Collections.Generic.List[string]
$ran     = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]
$detail  = New-Object System.Collections.Generic.List[string]

# ============ 0) KABUK ARTIGI FILTRESI ============
# Ortamdaki bir arac (buyuk olasilikla prompt metnini kabuktan geciren bir hook)
# zaman zaman sifir baytlik, bozuk/parantezli isimli dosyalar birakiyor; iki kez
# commit'e sizdilar. Sifir baytlik + supheli isimli dosyalar commit'e giremez.
$junk = New-Object System.Collections.Generic.List[string]
foreach ($f in $staged) {
  $suspicious = ($f -match '[(){}<>|]') -or ($f -match '[^ -~]')
  if (-not $suspicious) { continue }
  $item = Get-Item -LiteralPath $f -ErrorAction SilentlyContinue
  if ($item -and -not $item.PSIsContainer -and $item.Length -eq 0) {
    git reset -q -- $f 2>$null | Out-Null
    Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
    $junk.Add($f)
  }
}
if ($junk.Count -gt 0) {
  $staged = @(git diff --cached --name-only 2>$null)
  if ($staged.Count -eq 0) {
    Emit ("Yalniz kabuk artigi vardi, silindi (commit yok): " + ($junk -join ', '))
    exit 0
  }
}

# ============ 1) SIR TARAMASI (her zaman calisir, araca bagli degil) ============
$selfPath = 'scripts/quality-gate-commit.ps1'

foreach ($f in $staged) {
  $fn = [System.IO.Path]::GetFileName($f)
  if ($fn -like '.env*' -and $fn -ne '.env.example') {
    if ($failed -notcontains 'sir-taramasi') { $failed.Add('sir-taramasi') }
    $detail.Add("yasak dosya stage'de: $f")
  }
}

$added = @(git diff --cached --unified=0 -- . ":(exclude)$selfPath" 2>$null) |
  Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' }

$secretPatterns = @(
  @{ name = 'APP_KEY degeri';       rx = 'APP_KEY\s*=\s*\S{8,}' },
  @{ name = 'DB_PASSWORD degeri';   rx = 'DB_PASSWORD\s*=\s*\S+' },
  @{ name = 'ozel anahtar blogu';   rx = '-----BEGIN [A-Z ]*PRIVATE KEY-----' },
  @{ name = 'AWS erisim anahtari';  rx = 'AKIA[0-9A-Z]{16}' }
)
foreach ($pat in $secretPatterns) {
  $hit = $added | Where-Object { $_ -match $pat.rx } | Select-Object -First 1
  if ($hit) {
    if ($failed -notcontains 'sir-taramasi') { $failed.Add('sir-taramasi') }
    $detail.Add("sir kalibi yakalandi: $($pat.name)")
  }
}
$ran.Add('sir-taramasi')

# ============ 2) MOBIL (yalniz apps/mobile degistiyse) ============
$mobileChanged = @($staged | Where-Object { $_ -like 'apps/mobile/*' })
if ($mobileChanged.Count -gt 0) {
  if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Push-Location (Join-Path $root 'apps/mobile')

    $out = (flutter analyze --no-pub 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
      $failed.Add('flutter-analyze')
      $detail.Add((@($out.Trim() -split "`n") | Select-Object -Last 2) -join ' | ')
    }
    $ran.Add('flutter-analyze')

    $out = (flutter test 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
      $failed.Add('flutter-test')
      $detail.Add((@($out.Trim() -split "`n") | Select-Object -Last 2) -join ' | ')
    }
    $ran.Add('flutter-test')

    Pop-Location
  } else {
    $skipped.Add('flutter (arac yok)')
  }
}

# ============ 3) API (yalniz apps/api degistiyse) ============
$apiChanged = @($staged | Where-Object { $_ -like 'apps/api/*' })
if ($apiChanged.Count -gt 0) {
  $api = Join-Path $root 'apps/api'
  $phpOk = (Get-Command php -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $api 'vendor'))
  if ($phpOk) {
    Push-Location $api

    if (Test-Path 'vendor\bin\pint.bat') {
      $out = (& 'vendor\bin\pint.bat' --test 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) {
        $failed.Add('pint')
        $detail.Add((@($out.Trim() -split "`n") | Select-Object -Last 2) -join ' | ')
      }
      $ran.Add('pint')
    } else { $skipped.Add('pint (arac yok)') }

    if (Test-Path 'vendor\bin\phpstan.bat') {
      $out = (& 'vendor\bin\phpstan.bat' analyse --no-progress 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) {
        $failed.Add('phpstan')
        $detail.Add((@($out.Trim() -split "`n") | Select-Object -Last 2) -join ' | ')
      }
      $ran.Add('phpstan')
    } else { $skipped.Add('phpstan (arac yok)') }

    $out = (php artisan test 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
      $failed.Add('php-test')
      $detail.Add((@($out.Trim() -split "`n") | Select-Object -Last 2) -join ' | ')
    }
    $ran.Add('php-test')

    Pop-Location
  } else {
    $skipped.Add('php/composer (kurulum eksik)')
  }
}

# ============ KARAR ============
if ($failed.Count -gt 0) {
  git reset -q 2>$null | Out-Null
  $why = ($failed | Select-Object -Unique) -join ', '
  $ayrinti = (@($detail) | Select-Object -First 3) -join ' ; '
  Emit ("Kalite kapisi KIRMIZI - commit ATILMADI. Kirilan: $why. $ayrinti")
  exit 0
}

# --- Turkce commit mesaji + DECISIONS.md son karari ---
$lastDecision = ''
if (Test-Path 'DECISIONS.md') {
  $decisionLines = @(Get-Content 'DECISIONS.md' -Encoding UTF8 | Where-Object { $_.Trim().StartsWith('- ') })
  if ($decisionLines.Count -gt 0) { $lastDecision = $decisionLines[-1].Trim() }
  if ($lastDecision.Length -gt 220) { $lastDecision = $lastDecision.Substring(0, 217) + '...' }
}

$ozet = "otomatik($branch): $($staged.Count) dosya, kalite kapisi yesil"
$govde = "Kapi: " + (($ran | Select-Object -Unique) -join ', ')
if ($skipped.Count -gt 0) { $govde += " | atlanan: " + (($skipped | Select-Object -Unique) -join ', ') }
$msg = $ozet + "`n`n" + $govde
if ($lastDecision) { $msg += "`nSon karar: " + $lastDecision }

$tmp = Join-Path $env:TEMP ("sipario-commit-" + [guid]::NewGuid().ToString('N') + '.txt')
[System.IO.File]::WriteAllText($tmp, $msg, (New-Object System.Text.UTF8Encoding($false)))
git commit -F $tmp 2>&1 | Out-Null
$commitOk = ($LASTEXITCODE -eq 0)
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

if (-not $commitOk) {
  Emit 'Otomatik commit basarisiz (git commit hatasi) - degisiklikler stage''de duruyor.'
  exit 0
}

$hash = (git rev-parse --short HEAD 2>$null | Out-String).Trim()
git push origin $branch 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
  Emit ("Otomatik commit + push: $hash ($branch). Kapi: " + (($ran | Select-Object -Unique) -join ', '))
} else {
  Emit ("Otomatik commit yerel kaldi: $hash - push BASARISIZ (baglanti/kimlik?). Sonraki push'ta gider.")
}
exit 0
