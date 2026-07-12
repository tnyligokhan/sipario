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
| **Docker Desktop** | docker.com'dan indir, kur, başlat | Yerel PostgreSQL 16 bunda koşar. |
| **Laragon** | laragon.org'dan indir | PHP 8.3 + Composer için kullanıyoruz. Apache/vhost katmanı KULLANILMIYOR; proje Laragon'un `www` klasörüne taşınmaz. |
| **Node.js LTS (20+)** | `winget install OpenJS.NodeJS.LTS` | Ruflo/claude-flow ve hook'lar node ile çalışır. |
| **Claude Code** | `npm install -g @anthropic-ai/claude-code` | Geliştirme Claude Code ile yürür (aşağıda "Çalışma düzeni"). |
| **Flutter 3.38+** | flutter.dev → `flutter doctor` | Mobil taraf için. Android SDK cmdline-tools kur, `flutter doctor --android-licenses` ile lisansları onayla. |
| **Gerçek Android cihaz** | — | Arayan tanıma emülatörde kanıt sayılmaz (DECISIONS); pilot Xiaomi/Samsung ağırlıklı. |

### 2. PHP eklentilerini aç (Laragon varsayılanı KAPALI — atlarsan hiçbir şey çalışmaz)

Laragon → sistem tepsisinde sağ tık → **PHP → Extensions** → şunları işaretle:

- `pdo_pgsql` ve `pgsql` (Postgres bağlantısı — migrate/test bunsuz çalışmaz)
- `zip` (composer paket indirmek için)

Doğrula:

```powershell
php -m | findstr pgsql   # pdo_pgsql ve pgsql görünmeli
php -m | findstr zip     # zip görünmeli
```

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

> Sunucuyu başka bir makinede/projede elle eklemen gerekirse Windows'ta `npx`
> doğrudan çağrılamaz (`.cmd` dosyasıdır, "Failed to connect" alırsın);
> `cmd /c` ile sarmala:
> `claude mcp add claude-flow -- cmd /c npx -y ruflo@latest mcp start`

> Arka plan `daemon`'u OPSİYONEL ve sürekli token yakar — bilerek istemedikçe başlatma.

### 5. API'yi ayağa kaldır

```powershell
# 5a. Postgres'i başlat (host portu 55432 — 5432 DEĞİL; Laragon'un yerli
#     Postgres'i 5432'yi tuttuğu için bilinçli karar, DECISIONS.md'de)
docker compose up -d

# 5b. PHP bağımlılıkları
cd apps\api
composer install

# 5c. Ortam dosyası (.env git'te YOK — bilinçli; şablondan üret)
copy .env.example .env
php artisan key:generate

# 5d. Migration'lar (owner rolüyle koşulur — RLS tasarımı gereği)
php artisan migrate --database=pgsql_owner

# 5e. Deneme bayisi aç (istersen)
php artisan sipario:create-tenant "Deneme Bayi" "patron@ornek.tr" "Parola-123!"

# 5f. Testler — 34 test / 88 assertion, hepsi yeşil olmalı
php vendor\bin\phpunit

# 5g. Geliştirme sunucusu
php artisan serve        # http://127.0.0.1:8000, API: /api/v1/...
```

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
| `could not find driver (pgsql)` | php.ini'de `pdo_pgsql` kapalı → Adım 2. Geçici çare: `php -d extension=pdo_pgsql -d extension=pgsql artisan ...` |
| composer: "zip extension missing" | php.ini'de `zip` kapalı → Adım 2. |
| DB'ye bağlanıyor ama tablolar tuhaf/boş | Yanlış sunucuya bağlısın: Laragon'un yerli Postgres'i 5432'de. Bizim DB **55432**'de — `.env`'de `DB_PORT=55432` olduğunu doğrula. |
| Push reddedildi: "workflow scope" | Token'da Workflows izni yok → `gh auth login` ile tarayıcıdan yeniden gir veya PAT'e Workflows: Read/write ekle. |
| Testler `permission denied` / RLS hatası | Testler `sipario_app` rolüyle koşmalı (phpunit.xml doğru); migration'ı `--database=pgsql_owner` ile koştuğundan emin ol. |
| Docker volume bozuldu / sıfırlamak istiyorum | `docker compose down -v && docker compose up -d` (init betikleri rolleri ve test DB'sini yeniden kurar), sonra migrate. |
