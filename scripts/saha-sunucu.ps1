# SAHA SUNUCUSU — tek dosyayla ac/kapa (kullanici istegi 2026-07-28).
#
# Cift tiklanan SUNUCU-BASLAT.bat bu dosyayi calistirir. Sirayla:
#   0) Araclari BULUR (php, cloudflared) - PATH'e bagimli DEGILDIR
#   1) Docker acik degilse Docker Desktop'i baslatir ve bekler
#   2) sipario_db konteynerini ayaga kaldirir, saglikli olmasini bekler
#   3) Laravel API'yi gizli surec olarak baslatir (127.0.0.1:8000)
#   4) Cloudflare tunelini acar, adresi yakalar ve EKRANA arkadasina
#      gonderilecek hazir adresi yazar
#   5) ENTER'a basilinca ikisini de kapatir
#
# NOT — metinler bilerek ASCII (Turkce ozel harf yok): PowerShell 5.1, BOM'suz
# UTF-8 .ps1 dosyasini ANSI sanip Turkce harfleri bozuyor. Guvenilirlik oncelikli.
#
# NEDEN ARAC ARAMA VAR (2026-07-29 saha hatasi): script "php" ve "cloudflared"i
# PATH'te ariyordu; bu makinede ikisi de PATH'te DEGIL (php iki ayri yerde kurulu,
# cloudflared hic kurulu degil). Sonuc ham bir PowerShell istisnasiydi:
#   "Start-Process : ... Sistem belirtilen dosyayi bulamiyor."
# Bu mesaj ne eksik oldugunu SOYLEMIYOR. Iki gelistiricinin nobetlesip ayri
# makinelerde calistigi bir projede "benim makinemde PATH'te var" bir varsayimdir,
# sozlesme degil - script artik araclari kendisi bulur ve bulamazsa NE eksik
# oldugunu yazar.

$ErrorActionPreference = "Continue"
$kok     = Split-Path -Parent $PSScriptRoot         # depo koku (scripts\'in ustu)
$apiDir  = Join-Path $kok "apps\api"
$log     = Join-Path $env:TEMP "sipario-tunel.log"
$aracDir = Join-Path $PSScriptRoot ".araclar"       # indirilen yardimci ikililer (.gitignore'da)

function Yaz($m) { Write-Host $m }

# Sunucu surecini VE onun dogurdugu asil web sunucusunu kapatir.
#
# `artisan serve` bir SARMALAYICIDIR: istekleri karsilayan surec onun cocugu olan
# "php -S ..."tir. Yalniz sarmalayiciyi oldurmek cocugu yetim birakir; o da 8000 portunu
# tutmaya devam eder ve bir sonraki calistirma sessizce ESKI koda baglanir. Bu yuzden
# kapatma da komut satiri kalibina bakar, tek bir PID'e degil.
function Kapat-Sunucu($surec) {
  if ($surec) { Stop-Process -Id $surec.Id -Force -ErrorAction SilentlyContinue }
  Get-CimInstance Win32_Process -Filter "Name='php.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*artisan serve*" -or $_.CommandLine -like "*-S 127.0.0.1:8000*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Dur($mesaj) {
  Yaz ""
  Yaz "HATA: $mesaj"
  Yaz ""
  Read-Host "Kapatmak icin ENTER"
  exit 1
}

# php.exe'yi bul. Sira: PATH -> Laragon (en yeni surum) -> XAMPP.
# Surum kontrolu yapilir: Laravel 8.2+ ister ve eski bir php ile acilan sunucu
# anlasilmaz hatalarla duser - "php yok" demek "yanlis php" demekten iyidir.
function Bul-Php {
  $adaylar = New-Object System.Collections.ArrayList
  $g = Get-Command php.exe -ErrorAction SilentlyContinue
  if ($g) { [void]$adaylar.Add($g.Source) }
  if (Test-Path "C:\laragon\bin\php") {
    Get-ChildItem "C:\laragon\bin\php" -Directory -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending |
      ForEach-Object { [void]$adaylar.Add((Join-Path $_.FullName "php.exe")) }
  }
  [void]$adaylar.Add("C:\xampp\php\php.exe")

  foreach ($a in $adaylar) {
    if (-not (Test-Path $a)) { continue }
    $s = & $a -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>$null
    if (-not $s) { continue }
    $p = $s.Split('.')
    if ([int]$p[0] -gt 8 -or ([int]$p[0] -eq 8 -and [int]$p[1] -ge 2)) { return $a }
  }
  return $null
}

# pdo_pgsql yuklu mu? API Postgres kullanir (.env: DB_CONNECTION=pgsql); bu eklenti
# olmadan her istek "could not find driver" ile 500 doner.
#
# BURADA GECICI COZUM YOKTUR - VE BU BIR DERSTIR (2026-07-29'da iki kez odendi):
#   1. "php -d extension=pdo_pgsql artisan serve" ISE YARAMAZ. `artisan serve` isteklere
#      kendisi bakmaz; "php -S ..." ile AYRI bir surec dogurur ve komut satirindaki -d
#      bayraklari o cocuga GECMEZ. Ana surecte eklenti yuklu gorunur, sunucuda yuklu degildir.
#   2. PHP_INI_SCAN_DIR ortam degiskeni de GECMEZ: Laravel'in ServeCommand'i cocuga yalniz
#      beyaz listedeki degiskenleri aktarir (`$passthroughVariables`) ve bu degisken listede
#      yoktur. (Listedeki HERD_PHP_8x_INI_SCAN_DIR girdileri tam da bu yuzden vardir.)
# Yani eklenti php.ini'de ACIK olmak ZORUNDADIR. Bunu script'in kendisi yapmaz: php.ini
# makinenin tamami icindir (ayni PHP'yi kullanan diger projeler de onu okur) ve baskasinin
# ortamini sessizce degistirmek bu script'in isi degildir - NE yapilacagini SOYLER.
# Donen deger: $true (hazir) / $false (eksik).
function Pgsql-Var($phpExe) {
  $moduller = & $phpExe -m 2>$null | ForEach-Object { $_.Trim() }
  return ($moduller -contains "pdo_pgsql")
}

# cloudflared.exe'yi bul; yoksa resmi surumden BIR KEZ indirir (scripts\.araclar\).
# Indirilen dosya dogrulanir (boyut + --version): yarim inen bir exe, tunel adimini
# tesihi zor bir sekilde bozardi (APK indirmesindeki boyut kontrolunun ayni disiplini).
function Bul-Cloudflared {
  $g = Get-Command cloudflared.exe -ErrorAction SilentlyContinue
  if ($g) { return $g.Source }
  $yerel = Join-Path $aracDir "cloudflared.exe"
  if (Test-Path $yerel) { return $yerel }

  Yaz "cloudflared bulunamadi - resmi surumden indiriliyor (~50 MB, tek seferlik)..."
  if (-not (Test-Path $aracDir)) { New-Item -ItemType Directory -Path $aracDir -Force | Out-Null }
  $gecici = "$yerel.indiriliyor"
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $eskiIlerleme = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"   # PS 5.1'de ilerleme cubugu indirmeyi cok yavaslatir
    Invoke-WebRequest -UseBasicParsing `
      -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" `
      -OutFile $gecici
    $ProgressPreference = $eskiIlerleme
  } catch {
    Remove-Item $gecici -Force -ErrorAction SilentlyContinue
    return $null
  }
  if (-not (Test-Path $gecici) -or (Get-Item $gecici).Length -lt 5MB) {
    Remove-Item $gecici -Force -ErrorAction SilentlyContinue
    return $null
  }
  Move-Item $gecici $yerel -Force
  & $yerel --version *> $null
  if ($LASTEXITCODE -ne 0) { Remove-Item $yerel -Force -ErrorAction SilentlyContinue; return $null }
  Yaz "cloudflared hazir: $yerel"
  return $yerel
}

# ── 0) Araclar — Docker'a dokunmadan ONCE: eksik bir arac icin 2 dakika Docker
#       beklemek, sonra "php yok" demek kullanicinin zamanini bosa harcar.
$phpExe = Bul-Php
if (-not $phpExe) {
  Dur @"
PHP bulunamadi (8.2 veya ustu gerekli).

  Bakilan yerler: PATH, C:\laragon\bin\php\*, C:\xampp\php

  Cozum: XAMPP ya da Laragon kur; ya da kurulu php.exe'nin klasorunu PATH'e ekle.
"@
}
if (-not (Pgsql-Var $phpExe)) {
  $ini = & $phpExe -r "echo php_ini_loaded_file();" 2>$null
  if (-not $ini) { $ini = "(php.ini bulunamadi - 'php --ini' ile bak)" }
  Dur @"
PHP bulundu ama pdo_pgsql eklentisi KAPALI.
  PHP     : $phpExe
  php.ini : $ini

  API Postgres kullanir (.env: DB_CONNECTION=pgsql); bu eklenti olmadan her istek
  "could not find driver" ile 500 doner.

  Cozum (tek seferlik): php.ini dosyasini ac, su iki satirin basindaki ';' isaretini kaldir:
      ;extension=pdo_pgsql   ->   extension=pdo_pgsql
      ;extension=pgsql       ->   extension=pgsql
  Kaydet ve bu pencereyi yeniden calistir.
"@
}
Yaz "PHP: $phpExe"

$cfExe = Bul-Cloudflared
if (-not $cfExe) {
  Dur @"
cloudflared bulunamadi ve indirilemedi (internet baglantisi?).

  Elle kurmak icin: winget install --id Cloudflare.cloudflared
  ya da su dosyayi indirip $aracDir klasorune 'cloudflared.exe' adiyla koy:
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
"@
}

# ── 0b) Onceki calisandan kalan surecleri temizle (pencere X ile kapatilmis olabilir)
#
# IKI kalip da aranir ve bu SART (2026-07-29'da 5 yetim surec bulundu): "artisan serve"
# yalnizca SARMALAYICI surecin komut satiridir; istekleri karsilayan asil surec
# "php -S 127.0.0.1:8000 ...server.php"dir ve sarmalayici olunce O KALIR. Sonucu sinsidir:
# olu sunucu 8000 portunu tutmaya devam eder, yeni sunucu porta baglanamayip sessizce oger,
# script'in "API hazir mi" kontrolu ise ESKI surece cevap verdirip YESIL yanar. Yani ekranda
# her sey yolunda gorunurken bayi bir onceki calistirmanin koduna baglanir.
Get-CimInstance Win32_Process -Filter "Name='php.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like "*artisan serve*" -or $_.CommandLine -like "*-S 127.0.0.1:8000*" } |
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

# ── 1b) Sema + demo verisi
#
# NEDEN BURADA (2026-07-29): konteyner "healthy" olmasi veritabaninin HAZIR oldugu anlamina
# gelmez - bu makinede konteyner saglikliydi ama SEMA BOSTU (tek tablo yok). Sonuc, teshisi
# zor bir 500'du: giris istegi daha oturum acmadan `cache` tablosunu okuyup patliyordu.
# "Docker calisiyor" ile "veritabani kullanilabilir" iki ayri sorudur.
#
# migrate EK YAPAR, silmez (`migrate:fresh` BURADA ASLA CALISTIRILMAZ - kirmizi cizgi: para
# kayitlari silinmez). Bekleyen goc yoksa "Nothing to migrate" deyip ciker, maliyeti bir saniye.
# Owner baglantisi SART: uygulama rolunun (sipario_app) DDL yetkisi yoktur (Faz 1 izolasyonu).
# DemoSeeder idempotenttir - demo bayisi varsa dokunmadan doner.
Push-Location $apiDir
& $phpExe artisan migrate --database=pgsql_owner --force *> $null
$gocKodu = $LASTEXITCODE
if ($gocKodu -ne 0) {
  Pop-Location
  Dur @"
Veritabani semasi kurulamadi (php artisan migrate).

  Sebebi gormek icin ELLE calistir:
  cd "$apiDir"; & "$phpExe" artisan migrate --database=pgsql_owner --force

  Sik sebep: .env icindeki DB_OWNER_USERNAME/PASSWORD ile konteynerdeki roller uyusmuyor.
"@
}
# SESSIZ ARIZA (2026-07-29'da odendi): bu satir eskiden `*> $null` idi ve seeder'in CIKTISINI
# de HATASINI da yutuyordu. Demo bayisi kurulurken global users_email_unique kisitina carpip
# yarida kaldi; script yine "Sema ve demo verisi hazir." dedi. Sonuc: girisi calisan ama her
# ekrani bos bir bayi ve teshis edilemeyen bir aksam. Ciktiyi TUTUYORUZ ve cikis kodunu
# kontrol ediyoruz.
#
# OLUMCUL DEGIL, ama SESSIZ de degil: demo verisi kurulamasa bile sunucu ayaga kalkar
# (mevcut bayiler calisir) - yalniz ekranda kirmizi bir uyari ve gercek sebep durur.
$seedCikti = (& $phpExe artisan db:seed --class=DemoSeeder --force 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
  Yaz ""
  Yaz "UYARI: Demo verisi kurulamadi (sunucu yine de aciliyor)."
  Yaz "  Sebep:"
  foreach ($satir in ($seedCikti -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 8)) {
    Yaz ("    " + $satir)
  }
  Yaz ""
} else {
  Yaz "Sema ve demo verisi hazir."
}
Pop-Location

# ── 2) API sunucusu (gizli surec)
$php = Start-Process -FilePath $phpExe `
  -ArgumentList "artisan","serve","--host=127.0.0.1","--port=8000" `
  -WorkingDirectory $apiDir -WindowStyle Hidden -PassThru
$apiHazir = $false
for ($i = 0; $i -lt 20; $i++) {
  $kod = & curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Accept: application/json" 2>$null
  if ($kod -eq "422") { $apiHazir = $true; break }
  Start-Sleep -Seconds 1
}
if (-not $apiHazir) {
  # Surec olduyse sebebini gosterelim: sessiz bir "acilamadi" teshis ettirmiyor.
  Kapat-Sunucu $php
  Dur @"
API acilamadi (php artisan serve).

  PHP: $phpExe
  Klasor: $apiDir

  Sebebi gormek icin bu komutu ELLE calistir (pencere acik kalir, hatayi yazar):
  cd "$apiDir"; & "$phpExe" artisan serve --host=127.0.0.1 --port=8000
"@
}
Yaz "API hazir."

# ── 3) Tunel
Yaz "Tunel aciliyor..."
$cf = Start-Process -FilePath $cfExe -ArgumentList "tunnel","--url","http://127.0.0.1:8000","--no-autoupdate" `
  -WindowStyle Hidden -RedirectStandardError $log -PassThru
$adres = $null
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 2
  $bul = Select-String -Path $log -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" -ErrorAction SilentlyContinue |
         Select-Object -First 1
  if ($bul) { $adres = $bul.Matches[0].Value; break }
}
if (-not $adres) {
  # IKISI de kapatilir: eskiden yalniz php durduruluyordu ve arkada sahipsiz bir
  # cloudflared kaliyordu (bir sonraki calistirmada 0. adim onu temizliyordu ama
  # o ana kadar bosuna calisir ve gunlugu kirletirdi).
  Kapat-Sunucu $php
  Stop-Process -Id $cf.Id -Force -ErrorAction SilentlyContinue
  Dur "Tunel adresi alinamadi. Internet baglantisini kontrol et. (Gunluk: $log)"
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
Yaz "  Giris: firma '111' - kullanici '111' - parola '1111'   (GECICI - saha testi kolayligi)"
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
Kapat-Sunucu $php
Stop-Process -Id $cf.Id -Force -ErrorAction SilentlyContinue
Yaz "Sunucu ve tunel kapatildi. (Veritabani konteyneri calisir birakildi - zararsiz.)"
Start-Sleep -Seconds 2
