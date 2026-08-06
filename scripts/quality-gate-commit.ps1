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
#
# ============ SURE BUTCESI — NEDEN TAM SUITE BURADA KOSMUYOR (2026-08-06) ============
#
# ARIZA: kapi commit'e HIC ULASAMIYORDU ve kimse sebebini bilmiyordu. Vardiya sonunda 36 dosya
# commit'siz kaldi; kullanici elle "pushla" demek zorunda kaldi. Belirti sinsiydi: dosyalar
# SAHNELENMIS halde duruyordu (git add -A satir 51'de kosmustu) ama commit yoktu.
#
# OLCUM (2026-08-06, bu makinede): pint 2sn + phpstan 3sn + `php artisan test` 599sn = 604sn.
# Bu kancanin `.claude/settings.json`daki timeout'u 600sn. Yani kapi zaman asimini DORT SANIYEYLE
# kaybediyordu. Sure test sayisiyla dalgalandigi icin bazen geciyor bazen gecmiyordu — yazi-tura.
# `flutter test` de eklendiginde (mobil dokunusu varsa) kayip garantiye doner.
#
# KARAR: YAVAS kontroller bu kancadan CIKARILDI, HIZLI olanlar kaldi.
#   Burada (bloklayan, ~25sn): sir taramasi · pint · phpstan · dart analyze
#   CI'da (bloklamayan):       api-ci.yml (tam API suite, gercek Postgres + RLS)
#                              saha-apk.yml `test` isi (flutter test) -> APK'yi KAPILAR
#
# NEDEN GUVENLI: api-ci.yml zaten `apps/api/**` dokunan HER push'ta tam suite'i kosuyordu, yani
# yerel kosum ZATEN TEKRARDI — ve CI'daki daha guclu (RLS rolleri gercekten kuruluyor). Mobil
# tarafta ise `flutter test` TEK bekciydi ve kaldirilmasi bozuk bir APK'nin dogrudan telefona
# gitmesi demek olurdu; bu yuzden ayni turda saha-apk.yml'e `test` isi eklendi ve derleme ona
# `needs:` ile bagli — test kirmiziysa APK URETILMEZ.
#
# BU KANCANIN ISI ARTIK: sir sizdirmayi ve bicim/tip hatasini durdurmak, sonra commit + push.
# Testin dogru yeri, gercek servislerin oldugu ve kimseyi bekletmeyen yerdir: CI.
# Buraya tekrar `artisan test` / `flutter test` EKLEME — ayni arizayi geri getirirsin.

$ErrorActionPreference = 'Continue'

function Emit([string]$msg) {
  @{ systemMessage = $msg } | ConvertTo-Json -Compress
}

# --- stdin + sonsuz dongu korumasi ---
# STDIN OKUMASI ZAMAN SINIRLI OLMAK ZORUNDA (2026-08-06, elle kosarken yakalandi).
# `ReadToEnd()` stdin YONLENDIRILMIS ama KAPATILMAMISSA sonsuza kadar bekler: EOF hic gelmez.
# Claude Code hook'u JSON'i yazip kapattigi icin uretimde isirmiyor, ama betigi elle ya da baska
# bir sarmalayicidan kosan herkes bu duvara carpiyor — ve belirti "kanca hicbir sey yapmadi"
# oluyor: `git add`e bile varilmadigi icin agac TERTEMIZ gorunuyor, hata da yok. Sessiz asilma.
# 2 saniye fazlasiyla yeter (yuk birkac yuz bayt); gelmezse payload'siz devam ederiz, cunku
# payload YALNIZ sonsuz dongu korumasi icin okunuyor.
$raw = ''
if ([Console]::IsInputRedirected) {
  try {
    $okuma = [Console]::In.ReadToEndAsync()
    if ($okuma.Wait(2000)) { $raw = $okuma.Result }
  } catch { }
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

# --- TEK KOSUM KILIDI (2026-08-05) ---------------------------------------------------------
#
# NEDEN VAR: bu betik `Stop` hook'una baglidir, yani HER AJAN turunu bitirdiginde ateslenir.
# Icinde `php artisan test` (~10 dk) ve `flutter test` vardir. Birden fazla ajan calisirken
# ayni anda 2-3 tam suite kosuyor, iki `migrate:fresh` birbirinin semasini dusuruyor ve suite
# ~130 SAHTE kirik veriyordu ("relation admin_users does not exist", 401, "0 kayit").
#
# Bu, 2026-08-04 gecesi dort ajanin ve lead'in ~3 saatini yedi: herkes kirmizinin kendi kodundan
# geldigini sandi, "baska bir ajan test kosuyor" sanildi, sonra "kendi phpunit cocugunu goruyorsun"
# denildi -- ucu de eksikti. Gercek sebep BU KANCANIN KENDISIYDI ve kimse ona bakmadi cunku
# commit mesajlari "kalite kapisi yesil" diyordu.
#
# `flutter test` tarafinda ayni carpisma `sqlite3.dll` native asset yarisina donusuyor
# (PathExistsException) -- hafizadaki "esizamanli flutter test" tuzaginin da kaynagi budur.
#
# DAVRANIS: kilidi alamayan kosum SESSIZCE cikar (exit 0). Kaybetmek zararsizdir -- kazanan kosum
# ayni agaci zaten kontrol edip commit'liyor; bu turda commit'lenmeyen degisiklik varsa bir
# sonraki Stop onu toplar. Kilit BEKLEMEZ: beklemek Claude'u dakikalarca askida birakirdi.
# KILIT DEGIL MUTEX: kilit DOSYASI her cikis yolunda silinmek zorundadir ve bu betikte bir
# dusan tek `exit 0` var; biri unutulursa kapi 25 dk boyunca kendini kilitler. Mutex'i ise
# isletim sistemi surec olunce KENDILIGINDEN birakir -- cokme, kill, timeout hicbiri bayat
# kilit birakmaz. Bekleme YOK (`WaitOne(0)`): kaybeden hemen cikar.
$mutex = New-Object System.Threading.Mutex($false, 'Global\SiparioKaliteKapisi')
$kilitAlindi = $false
try { $kilitAlindi = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $kilitAlindi = $true }
if (-not $kilitAlindi) {
  Emit 'Kalite kapisi ATLANDI: baska bir kosum suruyor (eszamanli suite = sahte kirmizi).'
  exit 0
}

# MUTEX YETMEZ: mutex yalnizca BU BETIGIN kopyalarini birbirinden korur. Bir ajan kendi
# terminalinden `php artisan test` kosarsa mutex'i tutmaz ve kanca onun ustune biner --
# 2026-08-05 02:33'te tam bu yasandi (02:29 ajan kosumu + 02:33 kanca kosumu ayni anda).
# Bu yuzden isletim sistemine de bakariz: baska bir `artisan test` sureci varsa atlanir.
# Kendi cocuk sureclerimiz henuz dogmadigi icin bu kontrol kendini gormez.
try {
  $baskaKosum = @(Get-CimInstance Win32_Process -Filter "Name='php.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'artisan\s+test|phpunit' })
  if ($baskaKosum.Count -gt 0) {
    $mutex.ReleaseMutex()
    Emit "Kalite kapisi ATLANDI: elle baslatilmis bir test kosumu suruyor ($($baskaKosum.Count) surec)."
    exit 0
  }
} catch { }

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
  # Hook, PATH guncellemesinden onceki oturumdan miras kalabilir; bilinen kurulum yolunu dene.
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue) -and (Test-Path 'C:\src\flutter\bin\flutter.bat')) {
    $env:Path = "$env:Path;C:\src\flutter\bin"
  }
  if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Push-Location (Join-Path $root 'apps/mobile')

    # dart analyze, flutter analyze DEGIL: bu makinede projenin Turkce-karakterli yolu
    # (Masaustu'ndeki u) flutter analyze'in LSP kanalini kiriyor (analysis server 255);
    # dart analyze ayni analizoru cokme olmadan kosuyor (2026-07-17'de dogrulandi).
    $out = (dart analyze 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
      $failed.Add('dart-analyze')
      $detail.Add((@($out.Trim() -split "`n") | Select-Object -Last 2) -join ' | ')
    }
    $ran.Add('dart-analyze')

    # `flutter test` BURADA KOSMUYOR — bkz. dosya basindaki "SURE BUTCESI" notu.
    # Mobil testler CI'da: .github/workflows/saha-apk.yml icindeki `test` isi.
    # O is KIRMIZIYSA APK DERLENMEZ, yani telefona bozuk surum GITMEZ (`needs: test`).

    Pop-Location
  } else {
    $skipped.Add('flutter (arac yok)')
  }
}

# ============ 3) API (yalniz apps/api degistiyse) ============
$apiChanged = @($staged | Where-Object { $_ -like 'apps/api/*' })
if ($apiChanged.Count -gt 0) {
  $api = Join-Path $root 'apps/api'

  # PHP'yi KENDİMİZ buluruz — PATH bir sözleşme değildir (2026-07-29'da iki kez ödendi).
  #
  # SESSİZ ARIZA: bu makinede php PATH'te yok (Laragon/XAMPP altında kurulu) ve eski kod
  # `Get-Command php` bulamayınca API bölümünün TAMAMINI "kurulum eksik" diye ATLIYORDU.
  # Sonuç: pint · phpstan · php artisan test aylarca HİÇ koşmadı, kapı yine de "yeşil" dedi
  # ve API değişiklikleri doğrulanmadan commit edildi. Kırmızıyı CI yakaladı (pint, 6 dosya) —
  # yani kapının işini uzaktaki hat yapıyordu. Bir bekçinin sessizce devre dışı kalması,
  # bekçinin hiç olmamasından KÖTÜDÜR: "yeşil" raporu güven üretir.
  $phpExe = $null
  $g = Get-Command php.exe -ErrorAction SilentlyContinue
  if ($g) { $phpExe = $g.Source }
  if (-not $phpExe -and (Test-Path 'C:\laragon\bin\php')) {
    $aday = Get-ChildItem 'C:\laragon\bin\php' -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName 'php.exe' } |
            Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($aday) { $phpExe = $aday }
  }
  if (-not $phpExe -and (Test-Path 'C:\xampp\php\php.exe')) { $phpExe = 'C:\xampp\php\php.exe' }

  $phpOk = $phpExe -and (Test-Path (Join-Path $api 'vendor'))
  if ($phpOk) {
    Push-Location $api

    # Araçlar .bat sarmalayıcılarıyla DEĞİL, bulunan php ile koşturulur: pint.bat/phpstan.bat
    # içeride düz `php` çağırır ve PATH'te php yoksa "'php' is not recognized" ile düşer —
    # yani sarmalayıcı, çözdüğümüz sorunu geri getirirdi.
    if (Test-Path 'vendor\bin\pint') {
      $out = (& $phpExe 'vendor\bin\pint' --test 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) {
        $failed.Add('pint')
        $detail.Add((@($out.Trim() -split "`n") | Select-Object -Last 2) -join ' | ')
      }
      $ran.Add('pint')
    } else { $skipped.Add('pint (arac yok)') }

    if (Test-Path 'vendor\bin\phpstan') {
      $out = (& $phpExe 'vendor\bin\phpstan' analyse --no-progress 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) {
        $failed.Add('phpstan')
        $detail.Add((@($out.Trim() -split "`n") | Select-Object -Last 2) -join ' | ')
      }
      $ran.Add('phpstan')
    } else { $skipped.Add('phpstan (arac yok)') }

    # `php artisan test` BURADA KOSMUYOR — bkz. dosya basindaki "SURE BUTCESI" notu.
    # API testleri CI'da: .github/workflows/api-ci.yml, push'ta gercek Postgres + RLS ile
    # (yereldeki kosumdan DAHA guclu: RLS rolleri gercekten kuruluyor, izolasyon sinaniyor).

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

# MESAJ DURUST OLMAK ZORUNDA: eskiden "kalite kapisi yesil" yaziyordu ve bu, tam suite'in
# kostugu izlenimini veriyordu. Kendi basarisini raporlayan arac supheli listesinden duser —
# 2026-08-04'te tam bu yuzden kimse kancadan suphelenmedi. Artik yalnizca GERCEKTEN kosanlar
# yazilir ve testlerin CI'da oldugu acikca belirtilir.
$ozet = "otomatik($branch): $($staged.Count) dosya, hizli kapi yesil"
$govde = "Hizli kapi: " + (($ran | Select-Object -Unique) -join ', ')
if ($skipped.Count -gt 0) { $govde += " | atlanan: " + (($skipped | Select-Object -Unique) -join ', ') }
$govde += "`nTestler CI'da: api-ci (apps/api) · saha-apk/test (apps/mobile)"
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
  Emit ("Otomatik commit + push: $hash ($branch). Hizli kapi: " + (($ran | Select-Object -Unique) -join ', ') + ". Testler CI'da kosuyor.")
} else {
  Emit ("Otomatik commit yerel kaldi: $hash - push BASARISIZ (baglanti/kimlik?). Sonraki push'ta gider.")
}
exit 0
