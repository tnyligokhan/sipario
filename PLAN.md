# PLAN.md — Yol Haritası ve Devir Durumu

> **Nasıl kullanılır:** Her oturuma başlarken Claude'a bu dosyayı, `BRIEF.md`'yi ve
> `DECISIONS.md`'yi okut. Vardiyanı bitirirken Claude'a "PLAN.md'nin güncel durum
> bölümünü güncelle" de — sonraki kişi kaldığın yerden devam eder. Sohbet geçmişi
> paylaşılmaz; **bu üç dosya + git geçmişi projenin tek ortak hafızasıdır.**

## Fazlar

| Faz | Kapsam | Durum |
|-----|--------|-------|
| 0 | Arayan tanıma kanıtı (gerçek cihazlarda go/no-go) | ✅ **KAPANDI — GO (şartlı)**, 2026-07-10 |
| 1 | Temel: Laravel API, Postgres+RLS, auth, izolasyon test matrisi | ✅ **KAPANDI** (güvenlik denetimi dahil, 2026-07-13) |
| 2 | Offline çekirdek: SQLite/Drift, outbox, senkron motoru, müşteri+sipariş | bekliyor |
| 3 | Defter: veresiye, kasa, ödeme tipleri, kupon, gün sonu | bekliyor |
| 4 | Kurye: atama, teslim kapatma, kasa devri (+iOS başlangıcı) | bekliyor |
| 5 | Para: site, iyzico, abonelik kilidi, yönetim paneli | bekliyor |
| 6 | Mağaza+hukuk: Play beyanları, demo hesap, KVKK/mesafeli satış | bekliyor |
| 7 | Antalya pilotu: 2–3 gerçek bayi | bekliyor |

## Güncel durum (son güncelleme: 2026-07-13 vardiya sonu)

- **FAZ 1 TAMAMEN KAPANDI — güvenlik denetimi + düzeltme bitti.** Önceki vardiyadan
  devreden "YARIM KALDI: API güvenlik denetimi" işi bu vardiyada baştan koşuldu,
  bulgular düzeltildi ve doğrulandı. Ayrıntılı kararlar DECISIONS.md "Faz 1 — güvenlik
  denetimi" bölümünde.
- **Düzeltilen bulgular:** F1 rate-limit (login+API `throttle`), F3 güvenlik başlıkları
  (`SecurityHeaders` middleware), F4 CORS kilidi (`config/cors.php`, env-driven origin,
  credentials kapalı), F2 Sanctum `token_prefix=sipario_` (token süresizliği offline-first
  gereği bilinçli korundu), F6 larastan/phpstan seviye 6 (4 tip bulgusu kök nedenden
  düzeltildi, baskılama yok).
- **Doğrulama (bu makinede, doğru php+eklentilerle elle koşuldu):**
  pint ✓ · phpstan seviye 6 **0 hata** ✓ · phpunit **37/37, 105 assertion** ✓ ·
  `composer audit` **CVE yok** ✓. 3 yeni test `SecurityHardeningTest`'te (429 rate-limit,
  güvenlik başlıkları, izinsiz origin CORS reddi); mevcut 34 izolasyon/auth testi bozulmadı.
- **Çalışma akışı (karar DECISIONS.md'de):** yan dal/worktree YOK; iş doğrudan dev'de,
  main'e yalnız dev→main PR ile. Faz 1 kodu daha önce main'e merge edilmişti (PR #4, #6);
  bu güvenlik turu dev'de, dev→main PR sıradaki insan kararı.
- **Kurulum notu — ÖNEMLİ (fresh checkout'ta yaşandı):** `apps/api/vendor` ve `.env`
  git'te YOK. Yeni makinede: `composer install` (zip eklentisi gerekli:
  `php -d extension=zip composer.phar install`), `.env`'i `.env.example`'dan kopyala,
  `php artisan key:generate`. Docker Postgres **127.0.0.1:55432** (`docker compose up -d`;
  ilk initdb roller+`sipario_test`'i kurar). php.ini'de `pdo_pgsql`/`pgsql`/`zip` KAPALI
  (Laragon varsayılanı) → testler `php -d extension=pdo_pgsql -d extension=pgsql
  -d extension=zip vendor\phpunit\phpunit\phpunit` ile; `php artisan test` alt-sürece
  `-d` geçirmediğinden "could not find driver" verir, doğrudan phpunit çağır.
- **Kalite kapısı (Stop hook) bu makinede API kontrollerini ATLAR:** hook `Get-Command php`
  ile arıyor, php PATH'te değil → "atlanan: php/composer (kurulum eksik)". CI'da (php+
  eklentiler açık) phpstan/pint/test gerçekten koşar. Bu vardiyanın kontrolleri elle
  doğrulandı (yukarıda). php'yi kalıcı PATH'e/ini'ye almak sonraki tercih.
- **İzolasyon matrisi hâlâ yeşil:** 34/34 (+3 güvenlik = 37), gerçek Postgres 16, RLS'i
  atlayamayan `sipario_app` rolüyle. RouteCoverageGuardTest testsiz endpoint'i build'de kırar.
- **YARIM KALAN İŞ YOK — vardiya temiz kapandı.** Ağaç temiz, her şey commit + dev'e push'landı.
- **SONRAKİ KİŞİ BURADAN DEVAM ETSİN:**
  1. İstenirse **dev→main PR** aç ("PR aç" de) — Faz 1 güvenlik turunu main'e taşır (merge insanda).
  2. Kod işi = **Faz 2 — offline çekirdek**: SQLite/Drift şeması (server tablolarının aynası,
     UUIDv7 kimlikler istemcide), **outbox** tablosu (yazma yolu outbox üzerinden — DECISIONS
     "Senkron"), senkron motoru (tenant başına monoton `sequence` ile delta pull + ilk kurulumda
     tam snapshot; her olayda `client_event_id` ile idempotent retry), müşteri + sipariş CRUD.
     Senkron çakışma/birleşme kuralları DECISIONS "Senkron" ve "Veri modeli"nde hazır — yeniden
     tartışma, uygula. Not: defter tutarlılığı (korku #2) asıl Faz 3 ama `ledger_entries`/
     `order_events` şema kararları Faz 2'de atılmalı ki outbox baştan doğru olsun.
- Faz 0 durumu değişmedi (GO şartlı, ayrıntı DECISIONS.md).

## Faz 1 — yapılan işler (hepsi ✅)

1. ✅ `docker-compose.yml`: Postgres 16, TR locale (ICU), adlandırılmış volume, port 55432
2. ✅ `.env.example` + `config/database.php` (pgsql=app rolü, pgsql_owner=migration)
3. ✅ Migration'lar: `tenants`, `users`, `devices` (UUIDv7, istemci üretimli kimlik)
4. ✅ RLS politikaları migration içinde; `app.tenant_id` yoksa sıfır satır + FORCE RLS
5. ✅ Auth: Sanctum, patron/operatör/kurye, cihaz kaydı; login zamanlama yan-kanalı kapalı
6. ✅ Cross-tenant izolasyon matrisi + route kapsam bekçisi; CI'da postgres:16 service
7. ✅ Faz kapısı: izolasyon matrisi yeşil + auth akışı çalışıyor → **Faz 2'ye hazır**

## Faz 2'ye devreden küçük işler

- ✅ larastan/phpstan eklendi (seviye 6, kalite kapısı `vendor\bin\phpstan.bat` bulunca koşar).
- Kalan düşük öncelikli notlar: logout için ayrı izolasyon assertion'ı;
  `personal_access_tokens`'ın bilinçli RLS'sizliği (raw-SQL eklenirse hatırla);
  429 throttle yanıtlarına `server_time` istenirse `AppendServerTime` exception yolunu da kapsamalı;
  kalite kapısının API kontrollerini bu makinede koşabilmesi için php'yi PATH'e + eklentileri ini'ye almak.

## Açık riskler / şartlar (Faz 0'dan devreden)

- `USE_FULL_SCREEN_INTENT` Play beyanı Faz 6'da onay riski taşıyor
- Stok Android gerçek cihazda test edilmedi (emülatörde doğrulandı)
- MIUI izinleri programla doğrulanamıyor; Xiaomi'li bayide kurulum birlikte yapılacak
- 20 aramalık sistematik ölçüm pilotun ilk haftasına devredildi (ölçüm ekranı üründe)

## Ortam gereksinimleri (yeni makine kurulumu)

- Flutter 3.38+, Android SDK (cmdline-tools + lisanslar), gerçek Android cihaz
- PHP 8.3 + Composer, Docker Desktop
- `apps/api/.env` git'te YOK (bilinçli) — `.env.example`'dan kopyala;
  gizli değerler git dışında, elden paylaşılır
- GitHub erişimi: `tnyligokhan/sipario`, çalışma dalı `dev` (main korumalı)

## Devir ritüeli (vardiya sonu)

1. Claude'a: "PLAN.md güncel durum bölümünü ve varsa yeni kararları DECISIONS.md'ye işle"
2. Ağacın temiz olduğunu doğrula (`git status`) — otomatik commit hook'u genelde halleder
3. `git push` gittiğinden emin ol (hook push'u başarısızsa söyler)
4. Yarım kalan iş varsa PLAN.md'ye "yarım kaldı: ..." satırı bırak
