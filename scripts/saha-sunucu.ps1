# SAHA SUNUCUSU — tek dosyayla ac/kapa (kullanici istegi 2026-07-28).
#
# Cift tiklanan SUNUCU-BASLAT.bat bu dosyayi calistirir. Sirayla:
#   1) Docker acik degilse Docker Desktop'i baslatir ve bekler
#   2) sipario_db konteynerini ayaga kaldirir, saglikli olmasini bekler
#   3) Laravel API'yi gizli surec olarak baslatir (127.0.0.1:8000)
#   4) Cloudflare tunelini acar, adresi yakalar ve EKRANA arkadasina
#      gonderilecek hazir adresi yazar
#   5) ENTER'a basilinca ikisini de kapatir
#
# NOT — metinler bilerek ASCII (Turkce ozel harf yok): PowerShell 5.1, BOM'suz
# UTF-8 .ps1 dosyasini ANSI sanip Turkce harfleri bozuyor. Guvenilirlik oncelikli.

$ErrorActionPreference = "Continue"
$kok    = Split-Path -Parent $PSScriptRoot          # depo koku (scripts\'in ustu)
$apiDir = Join-Path $kok "apps\api"
$log    = Join-Path $env:TEMP "sipario-tunel.log"

function Yaz($m) { Write-Host $m }

# ── 0) Onceki calisandan kalan surecleri temizle (pencere X ile kapatilmis olabilir)
Get-CimInstance Win32_Process -Filter "Name='php.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like "*artisan serve*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item $log -Force -ErrorAction SilentlyContinue

# ── 1) Docker
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Yaz "Docker kapali - Docker Desktop baslatiliyor (1-2 dakika surebilir)..."
  Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -ErrorAction SilentlyContinue
  $hazir = $false
  for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 3
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { $hazir = $true; break }
  }
  if (-not $hazir) { Yaz "HATA: Docker acilamadi. Docker Desktop'i elle acip tekrar dene."; Read-Host "Kapatmak icin ENTER"; exit 1 }
}
docker start sipario_db *> $null
Yaz "Veritabani bekleniyor..."
for ($i = 0; $i -lt 20; $i++) {
  $d = docker inspect --format "{{.State.Health.Status}}" sipario_db 2>$null
  if ($d -eq "healthy") { break }
  Start-Sleep -Seconds 2
}
Yaz "Veritabani hazir."

# ── 2) API sunucusu (gizli surec)
$php = Start-Process -FilePath "php" -ArgumentList "artisan","serve","--host=127.0.0.1","--port=8000" `
  -WorkingDirectory $apiDir -WindowStyle Hidden -PassThru
$apiHazir = $false
for ($i = 0; $i -lt 20; $i++) {
  $kod = & curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Accept: application/json" 2>$null
  if ($kod -eq "422") { $apiHazir = $true; break }
  Start-Sleep -Seconds 1
}
if (-not $apiHazir) { Yaz "HATA: API acilamadi (php artisan serve)."; Read-Host "Kapatmak icin ENTER"; exit 1 }
Yaz "API hazir."

# ── 3) Tunel
Yaz "Tunel aciliyor..."
$cf = Start-Process -FilePath "cloudflared" -ArgumentList "tunnel","--url","http://127.0.0.1:8000","--no-autoupdate" `
  -WindowStyle Hidden -RedirectStandardError $log -PassThru
$adres = $null
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 2
  $bul = Select-String -Path $log -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" -ErrorAction SilentlyContinue |
         Select-Object -First 1
  if ($bul) { $adres = $bul.Matches[0].Value; break }
}
if (-not $adres) {
  Yaz "HATA: Tunel adresi alinamadi. Internet baglantisini kontrol et."
  Stop-Process -Id $php.Id -Force -ErrorAction SilentlyContinue
  Read-Host "Kapatmak icin ENTER"; exit 1
}

# Tunelin ucundan gercekten API'ye ulasildigini dogrula (422 = form hatasi = uc nokta canli)
$tunelOk = $false
for ($i = 0; $i -lt 10; $i++) {
  $kod = & curl.exe -s -o NUL -w "%{http_code}" --max-time 15 -X POST "$adres/api/v1/auth/login" -H "Accept: application/json" 2>$null
  if ($kod -eq "422") { $tunelOk = $true; break }
  Start-Sleep -Seconds 2
}

# ── 4) Ozet
Yaz ""
Yaz "=============================================================="
Yaz "  SIPARIO SAHA SUNUCUSU CALISIYOR"
Yaz "=============================================================="
Yaz ""
Yaz "  Arkadasina gonderilecek SUNUCU ADRESI (uygulamadaki alan):"
Yaz ""
Yaz "     $adres/api/v1"
Yaz ""
if (-not $tunelOk) { Yaz "  UYARI: adres uretildi ama dogrulanamadi - yine de dene." ; Yaz "" }
Yaz "  Giris: firma 'demo' - kullanici 'demo' - parola 'demo1234'"
Yaz ""
Yaz "  APK (sabit adres, degismez):"
Yaz "     https://github.com/tnyligokhan/sipario/releases/download/saha/saha-arm64.apk"
Yaz ""
Yaz "  NOT: Tunel adresi her aciliste DEGISIR - yeni adresi arkadasina ilet."
Yaz "  Bu pencere acik kaldigi surece sistem calisir."
Yaz "=============================================================="
Yaz ""
Read-Host "KAPATMAK icin ENTER'a bas"

# ── 5) Kapat
Stop-Process -Id $php.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $cf.Id  -Force -ErrorAction SilentlyContinue
Yaz "Sunucu ve tunel kapatildi. (Veritabani konteyneri calisir birakildi - zararsiz.)"
Start-Sleep -Seconds 2
