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
| 2 | Offline çekirdek: SQLite/Drift, outbox, senkron motoru, müşteri+sipariş | ✅ **ÇEKİRDEK KAPANDI — test + inceleme yeşil** (2026-07-13) |
| 3 | Defter: veresiye, kasa, ödeme tipleri, kupon, gün sonu | bekliyor |
| 4 | Kurye: atama, teslim kapatma, kasa devri (+iOS başlangıcı) | bekliyor |
| 5 | Para: site, iyzico, abonelik kilidi, yönetim paneli | bekliyor |
| 6 | Mağaza+hukuk: Play beyanları, demo hesap, KVKK/mesafeli satış | bekliyor |
| 7 | Antalya pilotu: 2–3 gerçek bayi | bekliyor |

## Güncel durum (son güncelleme: 2026-07-13 — Faz 2 çekirdek kapandı, inceleme yeşil)

- **FAZ 2 OFFLINE ÇEKİRDEK KAPANDI — kod + test + kalite/güvenlik incelemesi bitti, HEPSİ YEŞİL.**
  Architect'in tasarımı (DECISIONS "Faz 2 — mimari") uygulandı; uygulama kararları DECISIONS
  "Faz 2 — uygulama (coder)"da. Test derinleştirmesi + inceleme + düzeltmeler aynı vardiyada kapandı.
- **İNCELEME SONUCU: YEŞİL (şartlı kapanış).** Kırmızı çizgiler tek tek doğrulandı — kiracı
  izolasyonu (11 tabloda ENABLE+FORCE RLS, güvenli varsayılan, bileşik FK, tenant_id oturumdan,
  cross-tenant referans doğrulaması), offline-first (outbox+yerel yazma tek transaction,
  client_event_id idempotency, FOR UPDATE monoton seq, olay bazında savepoint izolasyonu, veri
  kaybı senaryosu yok), KVKK (API'de sıfır PII log), para (her yerde int kuruş). 3 bulgu düzeltildi
  (aşağıda). Ayrıntı DECISIONS "Faz 2 — güvenlik/kalite incelemesi".
- **DÜZELTİLEN BULGULAR (inceleme turu):**
  1. **KRİTİK — append-only DB seviyesinde zorlanmıyordu (kırmızı çizgi #2):** 210 migration'ı
     `sipario_app`'e ledger_entries/order_events'te de UPDATE/DELETE veriyordu → append-only yalnız
     kod disipliniyle korunuyordu. Yeni migration `2026_07_13_000211_revoke_writes_on_append_only`:
     `REVOKE UPDATE, DELETE` (ledger_entries, order_events, sync_changes, processed_events;
     tenant_sync_state hariç — seq UPDATE'lenir). Yeni test `AppendOnlyLedgerTest` 42501
     permission-denied'i kanıtlıyor. FORCE RLS felsefesiyle simetrik askı.
  2. **Tester bulgusu:** order_lines.product_id / ledger_entries.related_order_id'de cross-tenant
     referans doğrulaması eksikti → `ChangeApplier` customer_id ile simetrik RLS-kapsamlı kontrol
     eklendi, kalıcı reddetme testleri.
  3. **Kalite:** `ChangeApplier.php` 516 satırdı (500 sınırı aşımı) → üçe bölündü
     (`ChangeApplier` 270 / `OrderChangeApplier` 238 / `SyncPayload` 40). İzlenen 0-baytlık kök
     kabuk artıkları (`'`,`true`,`Xiaomi`,`cursor`,`bölümünü`) `git rm` ile temizlendi.
- **Sunucu (apps/api):** 10 migration (`customers`, `customer_phones`, `customer_addresses`,
  `products`, `orders`, `order_lines`, `order_events`, `ledger_entries` + senkron altyapısı
  `tenant_sync_state`/`sync_changes`/`processed_events`) + Faz 2 RLS migration (11 tabloya
  ENABLE/FORCE + politika). 8 model (HasUuids, casts, @property). `SyncService` (push: FOR UPDATE
  seq kilidi, idempotency, olay bazında savepoint; pull: snapshot/delta) + `ChangeApplier`
  (LWW / append / sipariş olayları). `SyncController` + `SyncPushRequest`/`SyncPullRequest` +
  route'lar `POST/GET /api/v1/sync/push|pull`. `Provisioning` tenant_sync_state satırı ekler.
- **İstemci (apps/mobile):** Drift şeması (`lib/data/tables.dart` + `app_database.dart`, `.g.dart`
  COMMIT'li) — sunucu aynası MİNUS tenant_id, `sipario.db`/`customers`/`customer_phones`/
  `phone_last10` native sözleşmesi korundu. Outbox + sync_meta. UUIDv7 (`lib/data/ids.dart`).
  Repository'ler (`lib/repo/`: müşteri/ürün/sipariş — yerel yazma + outbox aynı transaction).
  Sync motoru (`lib/sync/`: `SyncApi` arayüz + HTTP impl, `SyncEngine` push/pull + apply +
  istemci çakışma kuralı).
- **Doğrulama (test + inceleme turu sonrası, reviewer tarafından bu makinede BAĞIMSIZ koşuldu — HEPSİ YEŞİL):**
  API → pint ✓ · phpstan seviye 6 **0 hata** ✓ · phpunit **66/66, 246 assertion** ✓ · composer audit CVE yok
  (Faz 1'in 37'si + Faz 2: tester'ın derinleştirdiği `SyncTest`/`TenantIsolationTest` cross-tenant &
  senkron sözleşme testleri + reviewer turunun `AppendOnlyLedgerTest` 9 testi; `RouteCoverageGuard`
  sync uçlarını kapsar).
  Mobil → `flutter analyze` **0 sorun** ✓ · `flutter test` **38/38** ✓ (tester +3: outbox atomikliği,
  UUIDv7 üretimi; repository + sync motoru + db smoke + Faz 0).
- **ORTAM NOTLARI (Faz 2'de yaşandı, sonraki kişi için):**
  - API: `larastan/phpstan` bu checkout'ta vendor'da YOKTU; `php -d extension=zip
    /c/ProgramData/ComposerSetup/bin/composer.phar install` ile kuruldu (lock'ta vardı).
    Test/analiz komutları Faz 1'deki gibi `php -d extension=pdo_pgsql -d extension=pgsql
    -d extension=zip ...`. Docker `sipario_db` konteyneri `docker start sipario_db` ile ayağa kalktı.
  - Mobil: **Drift codegen Dart 3.10'da `dart run build_runner`ı kırıyor** (`sqlite3>=3.3` ve
    `objective_c` native hook'ları). `path_provider` kaldırıldı (objective_c gitti), üretilmiş
    `.g.dart` commit'lendi. Şema DEĞİŞİRSE: pubspec sonundaki kapalı `dependency_overrides:
    sqlite3 <3.3` bloğunu geçici aç → `flutter pub get && dart run build_runner build` → override'ı
    yine kapat → `flutter pub get`. `flutter test`/runtime override KAPALI ister (sqlite3 3.4).
- **BİLİNEN AÇIK / SONRAKİ KİŞİYE:**
  - `ledger_entries` şeması + sync hattı kuruldu; defteri ÜRETEN iş akışları (veresiye/kasa/kupon/
    gün sonu) **Faz 3**. Faz 2'de yalnız minimal `ledger.entry` kabulü + bakiye önbelleği tazeleme var.
  - Drift `journal_mode=TRUNCATE` native salt-okunur açıcı için ayarlandı ama **gerçek cihazda
    doğrulanmadı** (WAL riski açık — architect B.4). Faz 6 native entegrasyonunda sınanmalı.
  - Native arayan-tanıma tarafı Faz 2'de dokunulmadı; `customers.address` → `customer_addresses`
    normalizasyonu yapıldığından native adres okuması (varsa) ayrı sorguya taşınmalı (Faz 6).
  - UI minimal/yok (architect: "UI ayrıntısı sonraki iş"); repository katmanı hazır, ekranlar sonra.
- **SONRAKİ KİŞİ BURADAN DEVAM ETSİN:**
  1. İstenirse **dev→main PR** ("PR aç" de) — Faz 2 çekirdeğini main'e taşır (merge insanda).
     Faz 2 test + inceleme kapandı, kalite kapısı yeşil; PR'a hazır.
  2. Sonraki kod işi = **Faz 3 — defter** (veresiye/kasa/kupon/gün sonu); şema+sync hattı hazır,
     ledger append-only artık DB seviyesinde kilitli (düzeltme yalnız ters kayıtla — Faz 3 buna göre).
  3. Faz 2 açık devirleri (aşağıdaki "BİLİNEN AÇIK"): gerçek `HttpSyncApi` network testi
     (FakeSyncApi ile test edildi), Drift journal_mode gerçek cihaz doğrulaması (Faz 6), UI ekranları.
- Faz 1 tamamen kapalı (güvenlik denetimi dahil); Faz 0 GO (şartlı). Ayrıntı DECISIONS.md.

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
