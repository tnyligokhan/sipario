# Sipario

Türkiye'de eve servis yapan mikro esnaf (ilk hedef: su/damacana bayileri) için **sipariş + veresiye defteri + kurye takibi** uygulaması. Telefon çaldığında bayi müşteriyi anında tanır, birkaç dokunuşla sipariş girer, kurye teslim eder, akşam kasa ve borçlar net görünür. İnternet olmasa da çalışır, gelince senkronlanır.

> **Önce oku:** [`BRIEF.md`](BRIEF.md) (projenin anayasası) → [`DECISIONS.md`](DECISIONS.md) (verilmiş kararlar — yeniden tartışılmaz) → [`PLAN.md`](PLAN.md) (yol haritası + güncel durum + yarım kalan işler). Bu üç dosya + git geçmişi projenin **tek ortak hafızasıdır**; vardiyalar arasında sohbet geçmişi paylaşılmaz.

## Depo yapısı

```
apps/api      → Laravel 13 API (PHP 8.3, PostgreSQL 16 + RLS)
apps/mobile   → Flutter uygulaması (Android birincil, arayan tanıma native Kotlin)
docker/       → Postgres init betikleri (roller, test DB)
scripts/      → kalite kapısı, vardiya senkron kontrolü
.github/      → CI (postgres:16 service ile API testleri) + PR şablonu
```

---

## Sıfırdan kurulum (yeni makine, adım adım)

### 1. Temel araçlar

| Araç | Nasıl | Not |
|------|-------|-----|
| **Git** | `winget install Git.Git` | |
| **GitHub CLI (gh)** | `winget install GitHub.cli` → `gh auth login` | Tarayıcı ile giriş yap (HTTPS seç). PAT kullanacaksan token'da **Workflows: Read and write** izni olmalı, yoksa `.github/workflows` içeren push'lar reddedilir (yaşandı). |
| **Docker Desktop** | docker.com'dan indir, kur, başlat | **API tarafının TAMAMI bunda koşar**: PostgreSQL 16 · PHP 8.3 · Composer · web sunucusu. |
| ~~Laragon~~ | — | **GEREKMİYOR (2026-08-16'da kaldırıldı).** PHP artık `sipario_php` container'ında koşuyor; `pdo_pgsql`/`zip` eklentileri imajın içinde hazır geliyor. Makinende Laragon kurulu kalabilir, bu depo ona hiç bakmaz. |
| **Node.js LTS (20+)** | `winget install OpenJS.NodeJS.LTS` | Ruflo/claude-flow ve hook'lar node ile çalışır. |
| **Claude Code** | `npm install -g @anthropic-ai/claude-code` | Geliştirme Claude Code ile yürür (aşağıda "Çalışma düzeni"). |
| **Flutter 3.38+** | flutter.dev → `flutter doctor` | Mobil taraf için. Android SDK cmdline-tools kur, `flutter doctor --android-licenses` ile lisansları onayla. |
| **Gerçek Android cihaz** | — | Arayan tanıma emülatörde kanıt sayılmaz (DECISIONS); pilot Xiaomi/Samsung ağırlıklı. |

### 2. ~~PHP eklentilerini aç~~ — ARTIK GEREKMİYOR (2026-08-16)

Bu adım kaldırıldı. `pdo_pgsql` ve `zip`, PHP imajının (`serversideup/php:8.3-cli`) içinde
hazır geliyor; açılacak bir `php.ini` yok.

> **Neden bu adım vardı ve neden kaldırılması bir kazanç:** Laragon/XAMPP bu eklentileri
> KAPALI getirir ve kapalıyken her istek `could not find driver` ile 500 döner. Bu, bir
> vardiyanın başını yedi (2026-07-29) ve makineden makineye değişen bir kurulum adımıydı —
> yani "bende çalışıyor" ile "sende çalışmıyor" arasındaki farkın kaynağıydı. İmaja taşınınca
> herkeste aynı PHP, aynı eklentiler, aynı sürüm çalışır.

### 3. Depoyu klonla

```powershell
git clone https://github.com/tnyligokhan/sipario.git
cd sipario
git checkout dev        # ÇALIŞMA DALI dev'DİR; main korumalıdır
```

### 4. Ruflo / claude-flow kurulumu (Claude Code eklentisi)

MCP sunucu tanımı depoyla birlikte gelir (`.mcp.json` git'te takiplidir) — **`claude mcp add` ÇALIŞTIRMA**, "already exists" hatası alırsın. Yapman gereken sadece:

```powershell
# Proje kökünde Claude Code'u başlat; .mcp.json'daki claude-flow sunucusunu
# kullanmak isteyip istemediğini sorar -> onayla.
claude

# Doğrula (claude-flow satırında "Connected" görmelisin):
claude mcp list

# Tek seferlik sağlık kontrolü:
npx ruflo@latest doctor --fix
```

Ardından ruflo eklentilerini plugin marketten kur (proje kapsamında kuruludur,
her klonda yeniden kurulması gerekir):

```powershell
# Önce ruflo marketplace'ini ekle:
claude plugin marketplace add ruvnet/ruflo

# Sonra dört eklentiyi kur:
claude plugin install ruflo-adr@ruflo
claude plugin install ruflo-cost-tracker@ruflo
claude plugin install ruflo-security-audit@ruflo
claude plugin install ruflo-testgen@ruflo
```

Alternatif: Claude Code içinde `/plugin` yaz → marketplace ekle (`ruvnet/ruflo`) →
aynı dört eklentiyi arayüzden kur.

> Sunucuyu başka bir makinede/projede elle eklemen gerekirse Windows'ta `npx`
> doğrudan çağrılamaz (`.cmd` dosyasıdır, "Failed to connect" alırsın);
> `cmd /c` ile sarmala:
> `claude mcp add claude-flow -- cmd /c npx -y ruflo@latest mcp start`

> Arka plan `daemon`'u OPSİYONEL ve sürekli token yakar — bilerek istemedikçe başlatma.

### 5. API'yi ayağa kaldır

**Hiçbir komut host'taki PHP'yi çağırmaz** — hepsi container'ın içinde koşar. Giriş noktası
`scripts\api.ps1`; ne yaptığı ve neden var olduğu dosyanın başında yazılı.

```powershell
# 5a. Yığını başlat: Postgres + PHP + web sunucusu
#     (host portları: DB 55432, web 8000. DB'de 5432 DEĞİL — geliştirici
#      makinelerindeki yerli PostgreSQL'i gölgelememek için bilinçli karar,
#      DECISIONS.md'de)
docker compose up -d

# 5b. Ortam dosyası (.env git'te YOK — bilinçli; şablondan üret)
copy apps\api\.env.example apps\api\.env
.\scripts\api.ps1 artisan key:generate

# 5c. PHP bağımlılıkları (container'ın kendi vendor'üne kurulur)
.\scripts\api.ps1 -Kur

# 5d. Migration'lar (owner rolüyle koşulur — RLS tasarımı gereği)
.\scripts\api.ps1 artisan migrate --database=pgsql_owner

# 5e. Demo verisi: demo bayisi + panel yöneticileri
.\scripts\api.ps1 artisan db:seed
#     Bayi girişi  : firma kodu `demo` · kullanıcı `demo` · parola `demo1234`
#     Panel parolası RASTGELE üretilir; almak için:
#     .\scripts\api.ps1 artisan panel:admin "Adın" eposta@sipario.com.tr --sifirla

# 5f. Testler
.\scripts\api.ps1 artisan test

# 5g. Tarayıcıda aç — sunucu 5a'da zaten ayağa kalktı, ayrıca başlatmak gerekmez
#     http://localhost:8000            site
#     http://localhost:8000/panel/login  yönetim paneli
#     http://localhost:8000/api/v1/version  API sağlık kontrolü
```

> **`artisan serve`'ü elle çalıştırmana gerek yok** — `web` servisi onu container içinde
> koşuyor ve 8000 portunu host'a açıyor. Bu servis `php` servisinden AYRIDIR: web sunucusu
> bir sözdizimi hatasında ölse bile testler ve kalite kapısı çalışmaya devam etsin diye
> (gerekçe `docker-compose.yml`de yazılı).

Sorun çıkarsa: **Sorun giderme** bölümüne bak (en altta).

---

## Çalışma düzeni (pazarlıksız kurallar)

1. **Dal açma.** Yan dal/worktree yasak; iş **doğrudan `dev`'de** yapılır. main'e yalnız dev→main PR ile gidilir, merge kararı insanda. (DECISIONS.md, 2026-07-11)
2. **Oturuma başlarken** Claude'a `BRIEF.md`, `DECISIONS.md`, `PLAN.md`'yi okut. PLAN'daki "Güncel durum" ve "yarım kaldı" satırları kaldığın yeri söyler.
3. **Otomatik commit:** Claude Code Stop hook'u, kalite kapısı (analyze + test + pint + sır taraması) yeşilse dev'e otomatik commit+push eder. Kapı kırmızıysa commit olmaz.
4. **Vardiya biterken** Claude'a: "PLAN.md güncel durum bölümünü ve yeni kararları DECISIONS.md'ye işle" de; `git status` temiz ve push gitmiş olmalı; yarım iş varsa PLAN'a "yarım kaldı: ..." yaz.
5. **Kararlar** DECISIONS.md'nin SONUNA tek satır gerekçeyle eklenir; eskisi silinmez, değişen karar ~~üstü çizili~~ → yeni biçiminde güncellenir.

## Kırmızı çizgiler (özet — tamamı BRIEF.md'de)

- Bir bayi başka bayinin verisini ASLA göremez (RLS + cross-tenant test matrisi CI'da zorunlu).
- Para kayıtları silinmez/ezilmez; düzeltme ters kayıtla.
- Uygulama internetsiz TAM çalışır; senkron veri kaybetmez.
- KVKK: kişisel veri TR'de kalır; loglara/crash raporlarına PII yazılmaz.
- Mobilde kayıt/ödeme/fiyat ekranı YOK (mağaza politikaları); üyelik+ödeme yalnız web.
- Arayan tanıma yalnız `CallScreeningService` (Android 10+); SMS/Call Log izin grubu YASAK.

## Sorun giderme

| Belirti | Sebep / Çözüm |
|---------|---------------|
| `could not find driver (pgsql)` | Host'taki PHP'yi çağırıyorsun. Komutlar `.\scripts\api.ps1 ...` ile container'da koşar; eklentiler orada hazırdır. |
| `Docker daemon calismiyor` (kalite kapısı kırmızı) | Docker Desktop kapalı. Aç, bekle, tekrar dene. **Bu kapı bilerek kırmızı yanar** — eskiden sessizce atlıyordu ve pint/phpstan aylarca hiç koşmadı. |
| `vendor/doctrine does not exist and could not be created` | `vendor` volume'ü root sahipliğinde doğmuş. `docker compose up -d --build` (imaj dizini www-data sahipliğinde yaratır). |
| Sayfa açılmıyor (localhost:8000) | `docker compose ps` → `sipario_web` ayakta mı? Logu: `docker compose logs web`. |
| DB'ye bağlanıyor ama tablolar tuhaf/boş | Yanlış sunucuya bağlısın: makinede kurulu başka bir PostgreSQL 5432'de olabilir. Bizim DB **55432**'de (container içinden `db:5432`). |
| Push reddedildi: "workflow scope" | Token'da Workflows izni yok → `gh auth login` ile tarayıcıdan yeniden gir veya PAT'e Workflows: Read/write ekle. |
| Testler `permission denied` / RLS hatası | Testler `sipario_app` rolüyle koşmalı (phpunit.xml doğru); migration'ı `--database=pgsql_owner` ile koştuğundan emin ol. |
| Docker volume bozuldu / sıfırlamak istiyorum | `docker compose down -v && docker compose up -d` (init betikleri rolleri ve test DB'sini yeniden kurar), sonra migrate. |
