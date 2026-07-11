# PLAN.md — Yol Haritası ve Devir Durumu

> **Nasıl kullanılır:** Her oturuma başlarken Claude'a bu dosyayı, `BRIEF.md`'yi ve
> `DECISIONS.md`'yi okut. Vardiyanı bitirirken Claude'a "PLAN.md'nin güncel durum
> bölümünü güncelle" de — sonraki kişi kaldığın yerden devam eder. Sohbet geçmişi
> paylaşılmaz; **bu üç dosya + git geçmişi projenin tek ortak hafızasıdır.**

## Fazlar

| Faz | Kapsam | Durum |
|-----|--------|-------|
| 0 | Arayan tanıma kanıtı (gerçek cihazlarda go/no-go) | ✅ **KAPANDI — GO (şartlı)**, 2026-07-10 |
| 1 | Temel: Laravel API, Postgres+RLS, auth, izolasyon test matrisi | 🟢 **KOD TAMAM — PR dev'e açık, merge bekliyor** |
| 2 | Offline çekirdek: SQLite/Drift, outbox, senkron motoru, müşteri+sipariş | bekliyor |
| 3 | Defter: veresiye, kasa, ödeme tipleri, kupon, gün sonu | bekliyor |
| 4 | Kurye: atama, teslim kapatma, kasa devri (+iOS başlangıcı) | bekliyor |
| 5 | Para: site, iyzico, abonelik kilidi, yönetim paneli | bekliyor |
| 6 | Mağaza+hukuk: Play beyanları, demo hesap, KVKK/mesafeli satış | bekliyor |
| 7 | Antalya pilotu: 2–3 gerçek bayi | bekliyor |

## Güncel durum (son güncelleme: 2026-07-11, Faz 1 kapanışı)

- **Faz 1 kodu tamam, `faz1-temel` dalında; dev'e taslak PR açık — merge insan kararı.**
  Yapılanlar: docker-compose (Postgres 16, ICU tr-TR, adlandırılmış volume, host port
  **55432** — Laragon'un yerli 5432'siyle çakışmasın diye), 6 migration (tenants/users/
  devices + RLS ENABLE+FORCE + roller/grant'ler), Sanctum auth (patron/operatör/kurye),
  cihaz kaydı (istemci üretimli UUIDv7), `sipario:create-tenant` komutu, CI workflow'u.
- **İzolasyon matrisi yeşil: 34/34 test, 88 assertion, gerçek Postgres 16'ya karşı,
  RLS'i atlayamayan `sipario_app` rolüyle.** RouteCoverageGuardTest testsiz endpoint'i
  build'de kırar. Reviewer onayı: YEŞİL (kırmızı çizgi #1 ve #4 kanıtlı).
- **Faz 1 kapısı şartları sağlandı** (izolasyon matrisi yeşil + auth akışı çalışıyor);
  resmi kapanış PR merge ile.
- Mimari ayrıntılar ve tuzaklar (`sipario_owner`/`sipario_app`/`sipario_auth` rolleri,
  SECURITY DEFINER login, token'dan tenant çözme, SET LOCAL/transaction) `DECISIONS.md`
  "Faz 1 — uygulama" bölümünde.
- **Yeni makinede dikkat:** PHP'de `pdo_pgsql`+`pgsql` eklentileri php.ini'de açık
  olmalı (Laragon varsayılanı kapalı); Postgres artık **127.0.0.1:55432**.
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

- Login zamanlama yan-kanalı kapatıldı; kalan düşük öncelikli notlar: larastan eklenmesi
  (statik analiz şu an kalite kapısında "atlanan"), logout için ayrı izolasyon assertion'ı,
  `personal_access_tokens`'ın bilinçli RLS'sizliği (raw-SQL eklenirse hatırla).

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
