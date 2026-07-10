# PLAN.md — Yol Haritası ve Devir Durumu

> **Nasıl kullanılır:** Her oturuma başlarken Claude'a bu dosyayı, `BRIEF.md`'yi ve
> `DECISIONS.md`'yi okut. Vardiyanı bitirirken Claude'a "PLAN.md'nin güncel durum
> bölümünü güncelle" de — sonraki kişi kaldığın yerden devam eder. Sohbet geçmişi
> paylaşılmaz; **bu üç dosya + git geçmişi projenin tek ortak hafızasıdır.**

## Fazlar

| Faz | Kapsam | Durum |
|-----|--------|-------|
| 0 | Arayan tanıma kanıtı (gerçek cihazlarda go/no-go) | ✅ **KAPANDI — GO (şartlı)**, 2026-07-10 |
| 1 | Temel: Laravel API, Postgres+RLS, auth, izolasyon test matrisi | 🔨 **SIRADA** |
| 2 | Offline çekirdek: SQLite/Drift, outbox, senkron motoru, müşteri+sipariş | bekliyor |
| 3 | Defter: veresiye, kasa, ödeme tipleri, kupon, gün sonu | bekliyor |
| 4 | Kurye: atama, teslim kapatma, kasa devri (+iOS başlangıcı) | bekliyor |
| 5 | Para: site, iyzico, abonelik kilidi, yönetim paneli | bekliyor |
| 6 | Mağaza+hukuk: Play beyanları, demo hesap, KVKK/mesafeli satış | bekliyor |
| 7 | Antalya pilotu: 2–3 gerçek bayi | bekliyor |

## Güncel durum (son güncelleme: 2026-07-11)

- **Faz 0 kapandı.** Arayan tanıma Samsung S24 FE (And.16) ve Xiaomi 14 (HyperOS 2)
  üzerinde kanıtlandı: soğuk süreç, kilitli ekran, derin Doze, rehberli numara, giden
  arama, sıfır kurulum sihirbazı. Yasaklı izin yok. Ayrıntılar `DECISIONS.md`'de.
- **Otomatik commit disiplini kurulu:** Stop hook kalite kapısından (analyze+test+sır
  taraması) geçen işi dev'e otomatik commit+push eder; main/master korumalı.
- **Faz 1 henüz başlamadı.** `apps/api` temiz Laravel 12 iskeleti — dokunulmadı.
- Docker Desktop kuruldu (yerel Postgres 16 bunda koşacak).

## Faz 1 — sıradaki işler (sırayla)

1. `docker-compose.yml`: Postgres 16, TR locale, adlandırılmış volume
2. Laravel `.env` + `config/database.php` Postgres bağlantısı; `.env.example` güncelle
3. Migration'lar: `tenants`, `users`, `devices` (UUIDv7, istemci üretimli kimlik)
4. **RLS politikaları** migration içinde: her tabloda `tenant_id` policy;
   `app.tenant_id` set edilmemişse sıfır satır (güvenli varsayılan)
5. Auth: Sanctum token, patron/operatör/kurye rolleri, cihaz kaydı
6. **Cross-tenant izolasyon test matrisi**: her endpoint için "B'nin verisini A'nın
   token'ıyla iste → 404" otomatik testi; CI'da zorunlu (kırmızı çizgi #1)
7. Sıradaki faz kapısı: izolasyon matrisi yeşil + temel auth akışı çalışır durumda

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
