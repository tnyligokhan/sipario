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
# ($apiDir KALDIRILDI 2026-08-16: artisan artik container'in kendi working_dir'inde
#  kosuyor - /var/www/html, yani apps/api'nin ta kendisi.)
$log     = Join-Path $env:TEMP "sipario-tunel.log"
$aracDir = Join-Path $PSScriptRoot ".araclar"       # indirilen yardimci ikililer (.gitignore'da)

function Yaz($m) { Write-Host $m }

# Web sunucusunu kapatir.
#
# 2026-08-16'DAN ONCE bu fonksiyon bir SUREC AVIYDI ve olmasi gerekiyordu: `artisan serve`
# bir sarmalayicidir, istekleri karsilayan surec onun cocugu olan "php -S ..."tir; yalniz
# sarmalayiciyi oldurmek cocugu yetim birakir, o da 8000 portunu tutmaya devam eder ve bir
# sonraki calistirma sessizce ESKI koda baglanirdi (2026-07-29'da 5 yetim surec bulundu).
#
# ARTIK O SINIF ARIZA YOK: sunucu bir container'dir (`sipario_web`) ve container'in
# olmesi icindeki her sureci de goturur. Yetim surec kavrami ortadan kalkti - kapatma
# tek satir. Yukaridaki tarih bilerek duruyor: ayni tuzak, bir gun host'ta sunucu
# calistirmaya donulurse geri gelir.
function Kapat-Sunucu {
  docker compose --project-directory $kok stop web *> $null
}

function Dur($mesaj) {
  Yaz ""
  Yaz "HATA: $mesaj"
  Yaz ""
  Read-Host "Kapatmak icin ENTER"
  exit 1
}

# ── PHP ARAMA VE pdo_pgsql KONTROLU KALDIRILDI (2026-08-16) ──────────────────
#
# Buradaki iki fonksiyon (`Bul-Php`, `Pgsql-Var`) host'ta php.exe ariyor ve
# pdo_pgsql eklentisinin acik olup olmadigini olcuyordu. Ikisi de artik gereksiz:
# PHP `sipario_php`/`sipario_web` container'larinda kosuyor ve eklentiler imajin
# icinde HAZIR geliyor (`serversideup/php:8.3-cli`).
#
# ODENEN BEDELLER KAYIT ICIN DURUYOR - ikisi de kurulum FARKINDAN dogmustu:
#   · php PATH'te degildi, iki ayri yerde kuruluydu; script ham bir PowerShell
#     istisnasiyla oluyordu ve mesaj NE eksik oldugunu soylemiyordu (2026-07-29).
#   · pdo_pgsql Laragon/XAMPP'ta varsayilan KAPALI; kapaliyken her istek
#     "could not find driver" ile 500 donuyordu ve gecici cozumu YOKTU:
#     `php -d extension=pdo_pgsql artisan serve` ISE YARAMAZ (serve, istekleri
#     ayri bir "php -S" surecine devreder, -d bayraklari o cocuga gecmez),
#     PHP_INI_SCAN_DIR de gecmez (ServeCommand yalniz beyaz listedeki
#     degiskenleri aktarir).
#
# Her iki arizanin da ortak kaynagi suydu: PHP MAKINENIN, projenin degildi.
# Container bunu tersine cevirir - PHP artik projenin parcasi ve her makinede ayni.

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
# (PHP kontrolu artik burada YOK - container'da kosuyor, bkz. yukaridaki not.
#  Docker kontrolu asagida, 1) adiminda; oradan once yalniz cloudflared bakilir.)

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
# NOT (2026-08-16): buradaki php.exe surec avi KALDIRILDI - sunucu artik bir container
# ve container olunce icindeki her surec de oluyor, yani yetim surec kalmiyor. Yukaridaki
# aciklama gerekcesiyle birlikte duruyor cunku ders hala gecerli: host'ta sunucu
# calistirmaya donulurse ayni sinsi ariza geri gelir.
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
# `docker start sipario_db` DEGIL `docker compose up -d`: artik ayaga kalkmasi gereken
# UC servis var (db + php + web) ve `compose up` yoksa yaratir, varsa baslatir. Tek tek
# `docker start` yazmak, yeni bir servis eklendigi gun burayi sessizce eksik birakirdi.
Yaz "Yigin baslatiliyor (veritabani + PHP + web)..."
docker compose --project-directory $kok up -d *> $null
if ($LASTEXITCODE -ne 0) {
  Dur @"
Docker yigini baslatilamadi.

  Sebebi gormek icin ELLE calistir:
  cd "$kok"; docker compose up -d
"@
}
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
docker compose --project-directory $kok exec -T php php artisan migrate --database=pgsql_owner --force *> $null
$gocKodu = $LASTEXITCODE
if ($gocKodu -ne 0) {
  Dur @"
Veritabani semasi kurulamadi (artisan migrate).

  Sebebi gormek icin ELLE calistir:
  cd "$kok"; .\scripts\api.ps1 artisan migrate --database=pgsql_owner --force

  Sik sebep: .env icindeki DB_OWNER_USERNAME/PASSWORD ile konteynerdeki roller uyusmuyor.
  Ikinci sebep: bagimliliklar kurulmamis - `.\scripts\api.ps1 -Kur` calistir.
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
$seedCikti = (docker compose --project-directory $kok exec -T php php artisan db:seed --class=DemoSeeder --force 2>&1 | Out-String)
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

# ── 2) API sunucusu
#
# Sunucu 1) adiminda `compose up -d` ile ZATEN ayaga kalkti (servis adi: web). Burada
# yapilan tek is CEVAP VERDIGINI dogrulamaktir - "container ayakta" ile "API cevap
# veriyor" iki ayri sorudur ve bu ayrimin bedeli bu depoda bir kez odendi (konteyner
# saglikliydi ama sema bostu, giris istegi 500 donuyordu).
#
# SAGLIK OLCUSU 422: kimliksiz bir login istegi dogrulama hatasi dondurmelidir. 200
# beklemek yanlis olurdu (kimlik yok), 500 ise gercek bir ariza. 422 gormek, hem web
# sunucusunun hem PHP'nin hem de veritabaninin ayakta oldugunu TEK istekte kanitlar.
$apiHazir = $false
for ($i = 0; $i -lt 30; $i++) {
  $kod = & curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Accept: application/json" 2>$null
  if ($kod -eq "422") { $apiHazir = $true; break }
  Start-Sleep -Seconds 1
}
if (-not $apiHazir) {
  Kapat-Sunucu
  Dur @"
API acilamadi (sipario_web container'i cevap vermiyor).

  Sebebi gormek icin:
  cd "$kok"; docker compose logs web

  Sik sebep: bagimliliklar kurulmamis - `.\scripts\api.ps1 -Kur` calistir.
"@
}
Yaz "API hazir."

# ── 3) Tunel
#
# NEDEN PROTOKOL YEDEGI VAR (2026-08-04 saha arizasi - bayi HTTP 530 gordu):
# cloudflared varsayilan olarak QUIC (UDP 7844) ile baglanir. Bu makinenin agi UDP
# 7844'u kesiyordu. Sinsi olan su: ADRES YINE DE URETILIYOR - adres Cloudflare'in
# API'sinden gelir (port 443, acik), tunelin kendisiyle ilgisi yoktur. Yani script
# adresi yakaliyor, "hazir" deyip yesil yaniyor, bayi adrese giriyor ve Cloudflare
# "adres var ama arkasinda kimse yok" anlamina gelen HTTP 530 (Error 1033) donduruyor.
# Yerelde her sey saglam gorundugu icin teshis edilmesi zor bir arizaydi.
#
# Olculdu (ayni makine, ayni an): varsayilan protokol -> "Failed to dial a quic
# connection ... timeout", tunel HIC kurulmadi; "--protocol http2" -> "Registered
# tunnel connection ... protocol=http2", giris istegi 200 dondu. QUIC engellenen
# aglarda (Turkiye'de yaygin) TCP tabanli http2 calisir.
#
# Kural: ADRES ALMAK YETMEZ. Tunelin ucundan API'ye gercekten ulasildigi dogrulanir;
# dogrulanamazsa http2 ile YENIDEN denenir. Sessiz "yine de dene" uyarisi kaldirildi.
function Baslat-Tunel($cfExe, $log, $protokol) {
  Remove-Item $log -Force -ErrorAction SilentlyContinue
  $argumanlar = @("tunnel", "--url", "http://127.0.0.1:8000", "--no-autoupdate")
  if ($protokol) { $argumanlar += @("--protocol", $protokol) }
  $surec = Start-Process -FilePath $cfExe -ArgumentList $argumanlar `
    -WindowStyle Hidden -RedirectStandardError $log -PassThru

  $adres = $null
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 2
    $bul = Select-String -Path $log -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($bul) { $adres = $bul.Matches[0].Value; break }
  }
  if (-not $adres) {
    Stop-Process -Id $surec.Id -Force -ErrorAction SilentlyContinue
    return @{ Surec = $null; Adres = $null; Ok = $false }
  }

  # Tunelin ucundan gercekten API'ye ulasildigini dogrula (422 = form hatasi = uc nokta canli).
  # 530 burada yakalanir: adres cevap verir ama Cloudflare origin'e ulasamaz.
  $ok = $false
  for ($i = 0; $i -lt 10; $i++) {
    $kod = & curl.exe -s -o NUL -w "%{http_code}" --max-time 15 -X POST "$adres/api/v1/auth/login" -H "Accept: application/json" 2>$null
    if ($kod -eq "422") { $ok = $true; break }
    Start-Sleep -Seconds 2
  }
  return @{ Surec = $surec; Adres = $adres; Ok = $ok }
}

Yaz "Tunel aciliyor..."
$t = Baslat-Tunel $cfExe $log $null
if (-not $t.Ok) {
  Yaz "Tunel dogrulanamadi (QUIC/UDP engellenmis olabilir) - TCP (http2) ile yeniden deneniyor..."
  if ($t.Surec) { Stop-Process -Id $t.Surec.Id -Force -ErrorAction SilentlyContinue }
  $t = Baslat-Tunel $cfExe $log "http2"
  if ($t.Ok) { Yaz "http2 ile baglanti kuruldu." }
}
$cf      = $t.Surec
$adres   = $t.Adres
$tunelOk = $t.Ok

if (-not $adres) {
  # IKISI de kapatilir: eskiden yalniz php durduruluyordu ve arkada sahipsiz bir
  # cloudflared kaliyordu (bir sonraki calistirmada 0. adim onu temizliyordu ama
  # o ana kadar bosuna calisir ve gunlugu kirletirdi).
  Kapat-Sunucu
  if ($cf) { Stop-Process -Id $cf.Id -Force -ErrorAction SilentlyContinue }
  Dur "Tunel adresi alinamadi. Internet baglantisini kontrol et. (Gunluk: $log)"
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
#
# Yalniz `web` durdurulur; `db` ve `php` calisir birakilir. Gerekce: ikisi de disariya
# hicbir sey acmaz (`db` yalniz 127.0.0.1:55432, `php` hic port acmaz) ve ayakta
# kalmalari bir sonraki calistirmayi saniyeler icinde baslatir. Disariya acik olan tek
# sey tuneldi, o da kapandi.
Kapat-Sunucu
Stop-Process -Id $cf.Id -Force -ErrorAction SilentlyContinue
Yaz "Web sunucusu ve tunel kapatildi. (Veritabani ve PHP konteynerleri calisir birakildi - disariya kapali, zararsiz.)"
Start-Sleep -Seconds 2
