# PLAN.md — Yol Haritası ve Devir Durumu

> **Nasıl kullanılır:** Her oturuma başlarken Claude'a bu dosyayı, `BRIEF.md`'yi ve
> `DECISIONS.md`'yi okut. Vardiyanı bitirirken Claude'a "PLAN.md'nin güncel durum
> bölümünü güncelle" de — sonraki kişi kaldığın yerden devam eder. Sohbet geçmişi
> paylaşılmaz; **bu üç dosya + git geçmişi projenin tek ortak hafızasıdır.**

## İlerleme panosu (SABİT — her vardiya sonunda güncellenir)

> **Genel proje: ~%68** ⚠️ (2026-07-17 DÜZELTME: eski %79 yalnız sunucu+veri katmanını sayıyordu —
> **bayinin kullanacağı UI ekranları HİÇBİR fazın ağırlığında yoktu**; kullanıcı "APK alıp test
> edemez miyiz?" diye sorunca boşluk ortaya çıktı. Ağırlıklar yeniden dağıtıldı, "4b · Saha UI" satırı eklendi.)
> **Faz 4: ~%92 (mobil BU MAKİNEDE doğrulandı ✅)** · **Faz 5: ~%93** · **Faz 6: ~%22** · **4b UI: ~%35 (Dilim 1 ✅)**
> _(2026-07-17: Flutter kuruldu + mobil doğrulama YEŞİL + **UI Dilim 1 BİTTİ: giriş/oturum + ana kabuk +
> müşteri liste-arama-ekle-detay + abonelik şeridi + senkron servisi; 89/89 test, APK derlendi** ·
> kalan UI dilimleri: sipariş/teslim → defter/tahsilat/kupon/gün-sonu → kurye · dışsal işler YAPILACAKLAR.md)_

| Faz | Ağırlık | Durum | Katkı |
|-----|---------|-------|-------|
| 0 · Arayan tanıma kanıtı | %7 | ✅ kapandı | 7 |
| 1 · Temel (API/Postgres+RLS/auth) | %10 | ✅ kapandı | 10 |
| 2 · Offline çekirdek (Drift/outbox/sync) | %13 | ✅ kapandı | 13 |
| 3 · Defter (veresiye/kasa/kupon/gün sonu) | %10 | ✅ kapandı | 10 |
| 4 · Kurye (atama/teslim/kasa devri/+iOS) | %11 | 🔄 ~%92 (API✅ inceleme✅ mobil test✅; iOS açık) | ~10 |
| **4b · Saha UI (bayi+kurye ekranları)** | **%15** | 🔄 ~%35 (Dilim 1 ✅: giriş+kabuk+müşteri; kalan: sipariş/defter/kasa/kurye) | ~5 |
| 5 · Para (site/iyzico/abonelik/panel) | %17 | 🔄 ~%93 KOD TAM (dışsal: anahtar/hukuk) | ~16 |
| 6 · Mağaza + hukuk (Play/KVKK/mesafeli) | %10 | 🔄 ~%22 (demo hesap ✅ + metin paketi ✅ + hesap-silme ✅; kalan dışsal) | ~2 |
| 7 · Antalya pilotu (2–3 bayi) | %7 | ⬜ bekliyor (saha/insan) | 0 |
| **Toplam** | **%100** | | **~%68** |

> Ağırlıklar EFOR tahminidir (fazlar eşit büyüklükte değil); genel yüzde bu ağırlıklara göre hesaplanır.
> Bir faz kapandığında Katkı = tam Ağırlık olur ve genel yüzde artar. Mevcut faz yüzdesi kaba göstergedir:
> mimari/kod/test/inceleme dört kapısına göre biçilir. **2026-07-17 ağırlık düzeltmesi:** eski tablo
> UI eforunu hiç içermiyordu; her faz "UI sonraki iş" deyip devretmiş, iş sahipsiz kalmıştı. Eski
> satırlar ×0,85 küçültüldü, %15'lik "4b · Saha UI" eklendi — genel yüzdedeki düşüş (%79→%68) gerileme
> değil, ölçeğin dürüstleşmesidir.

## İnsan gerektiren işler (SENİN SIRAN — otonom modda bunlara takılmam, listeye yazıp devam ederim)

> Kullanıcı kararı (2026-07-15): "bana sormadan ajanlarla limit bitene kadar devam et." Dışsal/insan
> gerektiren şeyleri buraya biriktiriyorum; teknik her kararı kendim verip ilerliyorum.

- **[Faz 4]** Mobil doğrulama: partnerin **Flutter'lı makinesinde** `.g.dart` codegen + `flutter analyze` + `flutter test` (bu makinede Flutter yok). Yeşilse Faz 4 kapanır.
- **[Faz 4]** `dev→main` PR (#11) merge kararı insanda.
- **[Faz 5]** iyzico **üretim** hesabı + API anahtarları (geliştirme sandbox anahtarlarıyla yürür); site domain TLS; e-arşiv fatura sağlayıcı entegrasyon bilgileri. **⚠️ GÜVENLİK:** anahtar entegre edilirken `IyzicoPaymentGateway::verify()` MUTLAKA iyzico'ya sunucu-sunucu geri-sorgu + IYZWSv2 imza doğrulaması yapmalı (kod fail-closed kuruldu; smoke-test YETMEZ — gövde-güven = bedava abonelik açığı). Sandbox'ta forged-body reddi + gerçek retrieve sınanmalı.
- **[Faz 5c ortam]** `sipario_panel` DB rolü küme düzeyinde ELLE kuruldu (mevcut container); **CI/yeni makinede rol SQL'i elle koşulmalı** (Faz 1 sipario_app deseni). `.env`/`.env.example`'a `DB_PANEL_USERNAME=sipario_panel` + `DB_PANEL_PASSWORD=...` eklenmeli (config default'u var, testler yeşil; araç `.env*`'i koruyor).
- **[Faz 6]** Apple + Google Play geliştirici hesapları + mağaza başvurusu; `USE_FULL_SCREEN_INTENT` "çekirdek işlev" beyanı; KVKK aydınlatma + mesafeli satış/ön bilgilendirme metinlerinin **hukukça onayı**.
- **[Faz 7]** Antalya'da 2–3 gerçek bayi + gerçek Android cihazlar (pilot).

## Fazlar

| Faz | Kapsam | Durum |
|-----|--------|-------|
| 0 | Arayan tanıma kanıtı (gerçek cihazlarda go/no-go) | ✅ **KAPANDI — GO (şartlı)**, 2026-07-10 |
| 1 | Temel: Laravel API, Postgres+RLS, auth, izolasyon test matrisi | ✅ **KAPANDI** (güvenlik denetimi dahil, 2026-07-13) |
| 2 | Offline çekirdek: SQLite/Drift, outbox, senkron motoru, müşteri+sipariş | ✅ **ÇEKİRDEK KAPANDI — test + inceleme yeşil** (2026-07-13) |
| 3 | Defter: veresiye, kasa, ödeme tipleri, kupon, gün sonu | ✅ **KAPANDI — test + inceleme yeşil** (2026-07-14) |
| 4 | Kurye: atama, teslim kapatma, kasa devri (+iOS başlangıcı) | 🔄 **SÜRÜYOR** (mimari ✅, kod yazılıyor) |
| 5 | Para: site, iyzico, abonelik kilidi, yönetim paneli | 🔄 **KOD TAM** (sunucu ✅ inceleme ✅ güvenlik ✅ 163/163); dışsal: iyzico anahtar/hukuk prose/mobil |
| 6 | Mağaza+hukuk: Play beyanları, demo hesap, KVKK/mesafeli satış | bekliyor |
| 7 | Antalya pilotu: 2–3 gerçek bayi | bekliyor |

## Güncel durum (son güncelleme: 2026-07-17 — Flutter kuruldu, mobil doğrulandı, APK derlendi, UI boşluğu panoya işlendi)

### VARDİYA 2026-07-17/2 (Flutter kurulumu + mobil doğrulama + APK + pano düzeltmesi)

**TETİKLEYİCİ:** Kullanıcı "avukat/ödeme olmadan APK alıp test edemez miyiz?" diye sordu. Cevap iki katmanlı çıktı:
(1) Evet, mağaza/hukuk/ödeme TEST İÇİN GEREKMİYOR (onlar satış/mağaza koşulu); (2) ama APK alsak içinde
bayinin kullanacağı EKRAN YOK — her faz "UI sonraki iş" deyip devretmiş, iş hiçbir faza yazılmamış,
pano bu eforu hiç saymıyordu. Pano düzeltildi (%79→%68, "4b · Saha UI" %15 satırı eklendi).

### NE BİTTİ (bu vardiya — hepsi bu makinede koşulup doğrulandı)
- **Flutter 3.44.6 BU MAKİNEYE KURULDU** (`C:\src\flutter`, kullanıcı PATH'inde; SDK zip SHA256 doğrulandı).
  Android SDK zaten vardı; `cmdline-tools/latest` eklendi, lisanslar kabul, JDK = Android Studio JBR 21
  (`flutter config --jdk-dir`). `flutter doctor` temiz (tek eksik VS = Windows masaüstü, gerekmiyor).
- **YAPILACAKLAR madde 2 (mobil doğrulama) KAPANDI — partner bağımlılığı bitti:**
  codegen 62 çıktı (`.g.dart` 1.332 satır EKSİKMİŞ — Faz 4/5a şeması hiç üretilmemişti) →
  `dart analyze` temiz (1 GERÇEK hata bulundu+düzeltildi: `courier_test.dart` ambiguous `isNull`,
  drift import'una `hide isNull`) → **`flutter test` 72/72** → **debug APK uçtan uca derlendi**
  (`build/app/outputs/flutter-apk/app-debug.apk`, 150 MB debug-normal).
- **Türkçe-yol tuzakları çözüldü (yol: `OneDrive\Masaüstü` — ü AOT/LSP/AGP'yi kırıyor):**
  (a) `build_runner` AOT yazamıyor → **`--force-jit`**; (b) `flutter analyze` LSP çöküyor →
  **`dart analyze` kullan** (kalite kapısı scripti buna çevrildi + bilinen Flutter yolunu PATH'e
  ekleyen emniyet); (c) AGP ASCII-yol reddi → `gradle.properties`'e `android.overridePathCheck=true`.
- **Pano dürüstleştirildi:** UI eforu hiçbir fazda yoktu; "4b · Saha UI" %15 eklendi, eski ağırlıklar
  ×0,85; genel %79→%68. Faz 4 mobil testi doğrulandığından ~%85→~%92.

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. **4b Saha UI — Dilim 1 BİTTİ (aynı gün):** `lib/auth/` (AuthApi+Session — token sync_meta'da, deviceId
   kalıcı), `lib/sync/sync_service.dart` (periyodik push+pull, durum akışı), `lib/screens/` (login —
   mağaza kuralına uygun: kayıt/fiyat YOK; home_shell — 3 sekme + abonelik şeridi + salt-okunur kapısı;
   customers/ liste-arama-ekle-detay). Drift v6 (+authToken/userName/userRole/tenantName/apiBaseUrl).
   Test 89/89; testte bulunan GERÇEK hata: '0'lı telefon yazımı aramada eşleşmiyordu → normalize düzeltildi.
2. **SIRADAKİ KOD İŞİ = Dilim 2: sipariş ekranları** (yeni sipariş: müşteri+ürün satırları; açık sipariş
   listesi; teslim kapatma — ödeme tipi peşin/veresiye/kupon; OrderRepository.deliver hazır bekliyor).
   Sonra Dilim 3 (tahsilat/defter/gün-sonu), Dilim 4 (kurye+kasa devri; tek kişilik bayide gizle).
3. PR #11 hâlâ açık (Faz 3+4+5+6 → main), merge insanda. Dışsal işler `YAPILACAKLAR.md`.
4. **Kullanıcıya güncel APK verildi mi kontrol et:** `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`
   (Dilim 1'li). Telefon USB ile gelirse `adb install -r` + gerçek-cihaz doğrulaması (journal_mode/native).

### BİLİNEN TUZAKLAR (bu vardiya)
- **Mobil komut sırası (bu makine):** kısa yola cd (`/c/Users/bugra/OneDrive/MASAST~1/...`) güvenli;
  codegen `--force-jit` ŞART; analiz `dart analyze` (flutter analyze ÇÖKÜYOR, kapı scripti de dart analyze koşar).
- **`flutter build apk` ilk koşuda uzun** (Gradle+CMake indirir, ~5-8 dk); sonrakiler ~3 dk.
- **APK debug-imzalı** — telefona yan yükleme OK, Play'e YÜKLENEMEZ (YAPILACAKLAR madde 3: release anahtarı).
- **`android.overridePathCheck=true` commit'lendi** — ASCII-yollu makinelerde etkisiz, zararsız.

### VARDİYA 2026-07-17/1 (kısa vardiya — PR #11 tazelendi, kalite kapıları bağımsız doğrulandı)

**`main` FAZ 2'DE KALMIŞ — "bekliyor" görünümünün sebebi bu (kullanıcı fark etti, önemli).**
main son olarak PR #10'da (Faz 2) merge edildi; o günden beri **Faz 3+4+5+6 dev'de birikti: 40 commit,
123 dosya, +9.947/−347.** GitHub'da main'deki PLAN.md'ye bakan biri Faz 3–7'yi "bekliyor" görür ve
"kod işi kalmadı" ifadesiyle çelişir sanır — **çelişki yok, iş dev'de duruyor, main'e taşınmadı.**
Bu kafa karışıklığı tekrar etmesin: durum panosunun tek doğru kaynağı **dev'deki** PLAN.md'dir.

- **PR #11 yeniden yazıldı** — başlık "Faz 3 — Defter"di, dal ise Faz 3+4+5+6 taşıyordu; merge kararını
  verecek insan PR'a bakınca kapsamı YANLIŞ görüyordu. Yeni başlık/gövde: faz faz kapsam, 6 kırmızı
  çizginin kod düzeyinde kanıtı, doğrulama tablosu, bilinçli kapsam-dışı (dışsal) listesi.
  **PR durumu: MERGEABLE / CLEAN, CI iki kontrol de yeşil (test + manifest-lint). Merge düğmesi İNSANDA.**
- **Kalite kapıları bu makinede BAĞIMSIZ koşuldu (geçen vardiyanın iddiası doğrulandı):**
  phpunit **169/169 (587 assertion)** ✓ · pint temiz ✓ · phpstan sv6 **0 hata** ✓.
- **Yeni kod işi YAPILMADI** — çünkü yok: dışsal girdisiz (anahtar/Flutter/cihaz/avukat) iş geçen
  vardiyada tükendi; bu vardiya o iddiayı sınadı ve doğru buldu. Tam döküm `YAPILACAKLAR.md`.

**SONRAKİ KİŞİ:** (1) PR #11 merge edilirse main'deki pano da güncellenir ve "bekliyor" görüntüsü biter.
(2) Sunucuda dışsal-girdisiz iş yok — bir girdi gelince aç: iyzico sandbox anahtarı → ödeme akışı canlı
bağlanır; partnerde mobil codegen → Faz 4/5a kapanır; hukuk [köşeli]+avukat → 5d tamamlanır.

### VARDİYA 2026-07-16 (otonom, 6 ajan iki dalga + inline — HEAD `c4d9a27`, tam test 169/169, ağaç temiz).
Sunucu kodu (Faz 0–5) zaten bitmişti; kalan her şey dışsal. Anahtar/Flutter/cihaz GEREKTİRMEYEN tüm iç
işleri bitirdim + kullanıcı için tam yapılacaklar dökümanı çıkardım. iyzico'ya (anahtarsız doğrulanamaz)
ve mobile (Flutter yok) BİLEREK dokunulmadı.

### NE BİTTİ (bu vardiya)
- **5d hukuk (4 belge, `apps/api/resources/views/legal/docs/*.blade.php`):** mesafeli-satis (9 madde),
  on-bilgilendirme (Yönetmelik m.5), iptal-iade (cayma m.15/1-ğ), kvkk-aydinlatma (m.10/m.11 + veri
  sorumlusu/işleyen). PLACEHOLDER→gerçek Türkçe TASLAK; ⚠️ banner + `[köşeli]` (uydurma YOK) +
  her belgede B2B/tacir için `<!-- HUKUK NOTU: avukat -->`.
- **Faz 6 mağaza paketi (`docs/magaza/`, 5 md, ⚠️ TASLAK):** play-data-safety, play-listing,
  app-store-listing (iOS'ta arayan tanıma YOK açıkça), inceleme-notlari (demo hesap + "kayıt yok yalnız
  giriş" Apple 3.1.3-f/Play gerekçesi + FULL_SCREEN_INTENT beyanı + video PLACEHOLDER), README.
- **Google Play ZORUNLU hesap-silme sayfası (KOD+TEST):** `/hesap-silme` route (`account.deletion`) +
  view (`legal/hesap-silme.blade.php`) + `AccountDeletionPageTest` 2 test. Mağaza URL'leri bağlandı
  (silme URL + gizlilik = `/sozlesme/kvkk-aydinlatma`). İletişim/süre hâlâ [köşeli].
- **Kırmızı çizgi #6 regresyon bekçisi (KOD+CI) — audit bulgusu:** `check_permissions.sh` hiçbir CI'a
  bağlı değildi (DECISIONS "CI'da çalışır" diyordu, yanlıştı). İki katman kuruldu: `check_permissions_source.sh`
  (Flutter'sız kaynak-manifest denetimi, pozitif kontrolle doğrulandı: enjekte edilen `READ_PHONE_STATE`→exit 1)
  + `.github/workflows/manifest-lint.yml`. Merged-manifest katmanı mobil CI'a devredildi.
- **Uçtan-uca DENETİM (6 ajan: legal-reviewer + audit-phases + audit-redlines + audit-external-deps +
  legal-drafter + store-writer):** Faz 0–7 kod-belge örtüşüyor (uydurma yok), 6 kırmızı çizgi kod düzeyinde
  KANITLANDI, kritik açık yok. Düzeltilen tutarsızlıklar: pano %79/%80→%79; test sayısı 167→**169/169**
  (koşuldu, 587 assert, pint+phpstan sv6 0). Yeni dışsal bulgular: **Android release imza anahtarı**
  (build.gradle.kts TODO — debug-imzalı), **Mac/Xcode**, **e-arşiv sağlayıcı** (kodda yok), **VERBİS kaydı**.
- **`YAPILACAKLAR.md` OLUŞTURULDU** (kullanıcı talebi): proje sahibinin TÜM insan/dışsal işleri tek dökümanda,
  öncelikli (🔴/🟡/🟢), her kalemde NE/NEDEN/NASIL/kanıt + kırmızı-çizgi güvence bölümü. **Dışsal işlerin
  ARTIK KANONİK KAYNAĞI bu dosya.**

### NE YARIM KALDI / AÇIK (bu vardiya — tümü DIŞSAL, ayrıntı `YAPILACAKLAR.md`)
- **iyzico** gerçek sandbox/üretim anahtarı + `verify()` retrieve/imza GERÇEK testi (⚠️ smoke yetmez). BİLEREK dokunulmadı.
- **Mobil (Faz 4+5a)** codegen+analyze+test partnerde (Flutter yok, `.g.dart` STALE).
- **Hukuk** [köşeli] alanlar + avukat onayı; **mağaza** hesap/imza-anahtarı/video/görsel; **Faz 7** pilot.

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. **Önce `YAPILACAKLAR.md`'yi oku** — dışsal işlerin tam öncelikli dökümü orada.
2. Sunucuda test-edilebilir, dışsal-girdisiz yeni kod işi KALMADI (bu vardiya tükendi). Bir dışsal girdi gelince aç:
   (a) **iyzico sandbox anahtarı** → ödeme akışı canlı bağlanır + güvenlik testi koşulur;
   (b) partnerde **mobil codegen** → Faz 4/5a kapanır; (c) **hukuk [köşeli]+avukat** → 5d tamamlanır.
3. İstenirse **PR #11 (dev→main)** — o günden beri dev ilerledi, güncel dev'den yeniden gözden geçir.

### BİLİNEN TUZAKLAR (bu vardiya — sonraki kişi dikkat)
- **`YAPILACAKLAR.md` bu vardiyada eklendi** — dışsal iş listesi artık orada; PLAN "SENİN SIRAN" özet, tam liste YAPILACAKLAR'da (senkron tut).
- **Merged-manifest bekçisi HÂLÂ yok** — yalnız kaynak-manifest katmanı CI'da; 3. parti enjeksiyonunu ancak `check_permissions.sh` (gradle build) yakalar, mobil CI ile gelecek.
- **iyzico `initiate()` buyer/basketItems eksik** — alıcı adı/telefon/kimlik DTO'da yok; doldurmak Subscribe akışını değiştirir + anahtarsız doğrulanamaz → PARK (anahtar gelince sandbox'la yapılır).
- **Elle commit push-lag** — bu vardiya her commit kendi turunda push'landı (temiz); Stop hook'un push'una bel bağlama, `git rev-parse HEAD == origin/dev` ile teyit et.

### VARDİYA 2026-07-15 (önceki — Faz 4+5 KOD TAM)
Faz 4 (Kurye) + Faz 5 (Para) SUNUCU KODU TAMAM ve incelemeden geçti; 5d hukuk iskeleti + Faz 6 demo
hesabı kuruldu; CI YEŞİL (167/167).

### NE BİTTİ (sunucu, doğrulandı — phpunit 167/167, pint temiz, phpstan sv6 0, CI yeşil)
- **Faz 4 — Kurye (API):** olay-kaynaklı sipariş ATAMA (deterministik `(occurred_at,id)` türetme — sunucu+istemci simetrik), TESLİM İDEMPOTENSİ (deterministik uuid5 → iki cihaz offline teslim = TEK defter seti), KASA DEVRİ (append-only `cash_handovers`), nakit atfı (`collected_by_user_id`). Toplu inceleme YEŞİL.
- **Faz 5 — Para (sunucu tam):** 5a abonelik kilidi (`sync/push` enforcement, `locked_at` çıpası, durum yayını; okuma/pull ASLA kilitlenmez); 5b site+iyzico soyutlaması + **GÜVENLİK sertleştirme** (verify FAIL-CLOSED — forged-body bedava-abonelik açığı kapatıldı + tutar koruması); 5c-1/5c-2 yönetim paneli (`sipario_panel` salt-okunur DB rolü — panel iş verisini FİZİKSEL yazamaz; istatistik/export/modül/şifre-sıfırlama/cihaz); geri-dönen bayi web login. Faz 5 toplu inceleme YEŞİL.
- **5d hukuk İSKELET:** 4 belge şablonu (mesafeli satış/ön bilgilendirme/iptal-iade/KVKK) + `/sozlesme/{doc}` route + checkout onay linkleri (metinler PLACEHOLDER).
- **Faz 6 demo hesabı:** `DemoSeeder` — içi dolu AKTİF demo bayi (`demo@sipario.com.tr` / `demo1234`), 4 TELEFONLU müşteri (arayan-tanıma demosu) + defter; `php artisan db:seed --class=DemoSeeder`.
- **CI düzeltildi:** `sipario_panel` rolü CI workflow'una eklendi (migration 504 patlıyordu). Her şey origin/dev'de, **PR #11 (dev→main) Faz 3+4+5'i taşıyor — merge İNSANDA.**

### NE YARIM KALDI / AÇIK (tümü DIŞSAL — "SENİN SIRAN" listesi başta)
- **Mobil (Faz 4 + 5a) DOĞRULANMADI** — bu makinede Flutter yok; `.g.dart` STALE. **Partnerin Flutter makinesinde codegen + analyze + test şart.** Faz 4/5 bu yüzden BÜTÜN olarak kapanmadı.
- **iyzico** gerçek sandbox/üretim anahtarı + `verify()` retrieve/imza'nın GERÇEK testi (⚠️ güvenlik — smoke yetmez).
- **Hukuk metin prose'u** (5d iskelet hazır, tam metin + avukat onayı insan işi).
- **Faz 6** mağaza hesapları/başvuru + **Faz 7** pilot (saha).

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. İstersen **PR #11'i incele/merge** (Faz 3+4+5 main'e).
2. Tek bir dışsal girdiyle ilerlet: (a) **iyzico sandbox anahtarı** ver → gerçek ödeme akışı bağlanır+test edilir; (b) partnere **mobil codegen** koştur → mobil doğrulanır, Faz 4/5 kapanır; (c) **hukuk prose'unu** ver → 5d tamamlanır.
3. Sunucuda test-edilebilir yeni kod işi kalmadı; Faz 6/7 çoğunlukla insan/saha.

### BİLİNEN TUZAKLAR (sonraki kişi bunlara dikkat)
- **Flutter yok bu makinede** → mobil test/codegen partnerde. Şema değişince `.g.dart` stale kalır.
- **php PATH'te yok:** `/c/laragon/bin/php/php-8.3.30-Win32-vs16-x64/php.exe` + `-d extension=pdo_pgsql -d extension=pgsql -d extension=zip`. Docker: `docker start sipario_db`.
- **`sipario_panel` rolü küme düzeyinde** (docker init `10-roles.sh` yalnız İLK initdb'de koşar) → yeni makinede ELLE kur; CI'a eklendi (bu vardiya). Şifre `sipario_panel_dev` (phpunit.xml).
- **Elle commit push-lag:** ajan elle commit atınca origin geride kalır → "başlamamış mı?" yanılgısı. HER ZAMAN git tip'e bak; gerekirse `git push origin dev`. (Öneri: elle commit'i kendi turunda pushla.)
- **iyzico callback CSRF-muaf** → `verify()` gövdeye ASLA güvenmemeli (fail-closed kuruldu); anahtar gelince retrieve+imza gerçekten test edilmeli.
- **Drift codegen:** sqlite3 override `<3.0.0` (DECISIONS Faz 3); `.env*` araç-korumalı → `DB_PANEL_USERNAME/PASSWORD` elle eklenmeli.
- Ayrıntı: DECISIONS "Faz 4 — *", "Faz 5 — *", "Faz 5c — CI", "Faz 5d", "Faz 6 — hazırlık".

- **FAZ 3 — DEFTER KAPANDI (kod + test + kalite/güvenlik incelemesi bitti, HEPSİ YEŞİL).**
  Architect'in tasarımı (DECISIONS "Faz 3 — mimari") uygulandı; uygulama kararları DECISIONS
  "Faz 3 — uygulama (coder)"da. Para İMZALI çift-satır (debit+borç / payment−borç, ödeme tipiyle);
  kupon ADET (`coupon_movements` append-only + `coupon_balances` önbellek); gün sonu salt-okuma read-model.
- **İNCELEME SONUCU: YEŞİL — kırmızı çizgi ihlali YOK (reviewer, DECISIONS "Faz 3 — inceleme").** Beş
  kırmızı çizgi kod üzerinden tek tek doğrulandı: kiracı izolasyonu (kupon tablolarında ENABLE+FORCE RLS,
  bileşik `(tenant_id,reverses_*)` self-FK, TÜM yabancı id'lerde — customer/product/order/reverses —
  simetrik RLS-kapsamlı referans doğrulaması), append-only (coupon_movements DB seviyesinde UPDATE/DELETE
  REVOKE, düzeltme yalnız ters kayıt), offline-first (teslimat/kupon çoklu-yazım tek transaction atomik,
  kupon eksi bakiye reddedilmez), KVKK (sıfır PII log), para (her yerde int kuruş). Tester "gözlem B"si
  (ödeme düzeltmesi kasayı düzeltemiyor) inceleme sırasında coder+architect'çe kök nedenden kapatıldı,
  reviewer'ca doğrulandı. Bağımsız doğrulama reviewer'ca bu makinede TEKRAR koşuldu — hepsi yeşil.
  - **Sunucu (apps/api):** 5 migration (301 ledger alter: payment_type/reverses_entry_id + entry_type
    CHECK daralt + unique(tenant_id,id); 302 orders payment_type +kupon; 303 coupon_movements/
    coupon_balances; 304 RLS phase3; 305 coupon_movements REVOKE). Modeller `CouponMovement`/
    `CouponBalance` + `LedgerEntry` genişledi. `ChangeApplier::applyLedger` (işaret doğrulama +
    payment_type + reverses) + yeni `CouponChangeApplier` + `SyncService` snapshot. `SyncPushRequest`
    beyaz listesi `coupon`/grant/use/correction.
  - **İstemci (apps/mobile):** Drift v2→v3 additif migration (LedgerEntries +paymentType/reversesEntryId;
    CouponMovements/CouponBalances yeni). `lib/repo/ledger_ops.dart` (transaction'sız saf yazımlar),
    `LedgerRepository` (tahsilat/borç/alacak/düzeltme), `CouponRepository` (kuponSat/kuponDuzelt),
    `OrderRepository.deliver` genişledi (para/kupon deftere), `DayEndRepository` (kasa/borç/kupon salt-okuma).
    `sync_engine` coupon_movement/coupon_balance apply + ledger yeni kolonlar.
  - **Doğrulama (coder + tester turu, bu makinede koşuldu):** API → pint ✓ · phpstan sv6 **0 hata** ✓ ·
    phpunit **83/83, 310 assertion** ✓. Mobil → `flutter analyze` **0 sorun** ✓ · `flutter test` **52/52** ✓.
    (Faz 2 + Faz 3: peşin çift-satır, işaret doğrulama, kupon satış/kullanım/eksi-bakiye, cross-tenant kupon
    reddi, correction+payment_type kasa telafisi, gün sonu; tester derinleştirmesi + B düzeltmesi dahil.)
  - **TESTER B GÖZLEMİ UYGULANDI (architect onayı):** payment düzeltmesi artık kasayı da düzeltir. Kasa =
    `payment_type IS NOT NULL` kayıtların −amount toplamı (payment+correction, entry_type saymaz);
    `correction` payment_type taşıyabilir ve ters çevirdiği payment'ın tipini KOPYALAR → bakiye VE kasa
    telafi kaydıyla birlikte düzelir (BRIEF "kasa kuruşuna kuruşuna"). validateLedgerEntry payment_type'ı
    payment+correction'da kabul eder (debit/credit YASAK); kasaOzeti invariant'a geçti; LedgerRepository.
    duzeltme reversed kaydın payment_type'ını kopyalar. Ayrıntı DECISIONS "Faz 3 — uygulama".
  - **ORTAM NOTU (Faz 3'te yaşandı):** codegen sqlite3 override sınırı `<3.0.0` olmalı (eski `<3.3` artık
    kırılıyor — 3.2.0 sonradan build-hook kazandı; hook'suz son 2.9.4). pubspec notu düzeltildi.
  - **BİLİNEN AÇIK / FAZ 4'E DEVİR (Faz 3):**
    - **Sipariş-düzeyi teslim idempotensi yok:** iki cihaz aynı siparişi offline teslim ederse iki
      bağımsız ledger seti (çift debit/payment) üretir — append/birleşme deseninin doğal sonucu (kupon
      çifte-harcamayla simetrik, BRIEF kabul); düzeltme ters kayıtla kapanır. Çift-dokunma koruması +
      kalıcı kasa mutabakatı Faz 4 (kurye kasa devri) kapsamında ele alınmalı.
    - Gün sonu Faz 3'te SALT-OKUNUR read-model; **kurye kasa DEVRİ (kalıcı mutabakat kaydı) + atama Faz 4.**
    - Drift `journal_mode=TRUNCATE` native salt-okunur açıcı için ayarlı ama **gerçek cihazda
      doğrulanmadı** (WAL riski — architect B.4); Faz 6 native entegrasyonunda sınanmalı (Faz 2'den devam).
    - UI minimal/yok; repository katmanı hazır, ekranlar sonraki iş.
  - **SONRAKİ KİŞİ BURADAN DEVAM ETSİN:**
    1. İstenirse **dev→main PR** ("PR aç" de) — Faz 2+Faz 3'ü main'e taşır (merge insanda). Test + inceleme
       kapandı, kalite kapısı yeşil; PR'a hazır. (Faz 2 çekirdeği henüz main'e gitmediyse aynı PR'da gider.)
    2. Sonraki kod işi = **Faz 4 — kurye** (atama, teslim kapatma, kasa devri, +iOS başlangıcı); defter +
       append-only + kupon altyapısı hazır, teslim idempotensi + kalıcı kasa mutabakatı bu fazda kurulur.

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
