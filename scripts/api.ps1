# =============================================================================
#  Sipario - API tarafi icin TEK GIRIS NOKTASI (2026-08-16)
# =============================================================================
#
#  NE ISE YARAR: PHP artik host'ta degil, `sipario_php` container'inda kosar.
#  Bu script komutlari oraya gonderir ve cikis kodunu AYNEN geri verir.
#
#      .\scripts\api.ps1 artisan test
#      .\scripts\api.ps1 artisan migrate --database=pgsql_owner
#      .\scripts\api.ps1 composer install
#      .\scripts\api.ps1 pint --test
#      .\scripts\api.ps1 phpstan
#      .\scripts\api.ps1 -Kur              # yigini ayaga kaldir + composer install
#
#  NEDEN SARMALAYICI VAR, HERKES `docker compose exec` YAZMIYOR:
#  komutlar tek yerden gecerse yarin imaj/servis adi degistiginde TEK dosya
#  degisir. Bu depoda ayni ders bir kez odenmisti: php.exe arama mantigi iki
#  ayri script'e kopyalanmisti ve ikisi birbirinden habersiz bozulabiliyordu.
#
#  ============================================================================
#  ⚠️ EN ONEMLI DAVRANIS: SESSIZ ATLAMA YOK.
#  ============================================================================
#  `quality-gate-commit.ps1` icinde yazili bir kaza var: php PATH'te
#  bulunamayinca kalite kapisi API bolumunun TAMAMINI "kurulum eksik" diye
#  atliyordu; sonuc olarak pint, phpstan ve artisan test AYLARCA hic kosmadi ve
#  kapi yine de "yesil" dedi. Docker'a gecmek bu tuzagi YOK ETMEZ, KILIK
#  DEGISTIRIR: bu sefer "Docker kapali" ayni sessizligi uretebilirdi.
#  Bu yuzden burada Docker/container eksikse script HATA ile cikar (exit 2/3),
#  cagiran taraf bunu "atlandi" diye yorumlayamaz.
# =============================================================================

[CmdletBinding()]
param(
  [switch]$Kur,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Komut
)

$ErrorActionPreference = 'Stop'
$depoKok = Split-Path -Parent $PSScriptRoot

function Yaz([string]$metin, [string]$renk = 'Gray') { Write-Host $metin -ForegroundColor $renk }

# --- 1. Docker daemon ayakta mi? ---------------------------------------------
# `docker info` yeterli: `docker --version` daemon kapaliyken de basariyla doner
# ve "docker var" sanisi uretir - olculdu, bu ayrimi kaybetmek tam da yukarida
# anlatilan sessiz atlamanin kapisidir.
docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
if (-not $?) {
  Yaz "HATA: Docker daemon calismiyor." 'Red'
  Yaz "      Docker Desktop'i baslat, sonra tekrar dene." 'Yellow'
  exit 2
}

# --- 2. Container ayakta mi? Degilse kaldir ----------------------------------
$durum = (docker compose --project-directory $depoKok ps --status running --services 2>$null)
if ($durum -notcontains 'php') {
  Yaz "sipario_php ayakta degil - yigin baslatiliyor..." 'Cyan'
  docker compose --project-directory $depoKok up -d
  if ($LASTEXITCODE -ne 0) {
    Yaz "HATA: `docker compose up -d` basarisiz." 'Red'
    exit 3
  }
}

# --- 3. Kurulum modu ---------------------------------------------------------
if ($Kur) {
  Yaz "Bagimliliklar kuruluyor (container icinde)..." 'Cyan'
  docker compose --project-directory $depoKok exec -T php composer install --no-interaction --no-progress
  exit $LASTEXITCODE
}

if (-not $Komut -or $Komut.Count -eq 0) {
  Yaz "Kullanim: .\scripts\api.ps1 <komut>   (ornek: artisan test)" 'Yellow'
  Yaz "          .\scripts\api.ps1 -Kur      (composer install)" 'Yellow'
  exit 64
}

# --- 4. Kisayollari ac -------------------------------------------------------
# Sik kullanilan uc arac icin kisa ad; geri kalan her sey OLDUGU GIBI gecer.
# Kisayol listesi bilerek kisa: her kisayol, komutun gercekte ne kostugunu
# gizleyen bir katmandir ve hata ayiklamayi zorlastirir.
$ilk = $Komut[0]
$kalan = if ($Komut.Count -gt 1) { $Komut[1..($Komut.Count - 1)] } else { @() }

switch ($ilk) {
  'artisan'  { $tam = @('php', 'artisan') + $kalan }
  'pint'     { $tam = @('vendor/bin/pint') + $kalan }
  'phpstan'  { $tam = @('vendor/bin/phpstan', 'analyse', '--no-progress') + $kalan }
  'composer' { $tam = @('composer') + $kalan }
  'php'      { $tam = @('php') + $kalan }
  default    { $tam = $Komut }
}

docker compose --project-directory $depoKok exec -T php @tam
exit $LASTEXITCODE
