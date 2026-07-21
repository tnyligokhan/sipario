# PLAN.md — Yol Haritası ve Devir Durumu

> **Nasıl kullanılır:** Her oturuma başlarken Claude'a bu dosyayı, `BRIEF.md`'yi ve
> `DECISIONS.md`'yi okut. Vardiyanı bitirirken Claude'a "PLAN.md'nin güncel durum
> bölümünü güncelle" de — sonraki kişi kaldığın yerden devam eder. Sohbet geçmişi
> paylaşılmaz; **bu üç dosya + git geçmişi projenin tek ortak hafızasıdır.**

## İlerleme panosu (SABİT — her vardiya sonunda güncellenir)

> **Genel proje: ~%78** (2026-07-17 DÜZELTME tabanı: eski %79 yalnız sunucu+veri katmanını sayıyordu —
> UI eforu "4b · Saha UI" satırıyla panoya eklendi.)
> **Faz 4: ~%92** · **Faz 5: ~%93** · **Faz 6: ~%22** · **4b UI: ✅ KAPANDI (Dilim 1+2+3+4)**
> _(2026-07-21/3: **UI Dilim 4 BİTTİ — 4b TAMAMEN KAPANDI: kurye listesi sunucudan team bloğuyla,
> Drift v7 users aynası, K2 rol-yetki matrisi, atama UI, kasa devri ekranı, tek-kişilik gizleme;
> mobil 159/159 · API 174/174 · inceleme YEŞİL · APK derlendi · guzzle güvenlik yükseltmesi (4
> Dependabot uyarısı kapandı)**. KODLA YAPILABİLİR İŞ BİTTİ — kalan her şey dışsal/insan:
> YAPILACAKLAR.md + PR #11 merge + gerçek cihaz + pilot.)_

| Faz | Ağırlık | Durum | Katkı |
|-----|---------|-------|-------|
| 0 · Arayan tanıma kanıtı | %7 | ✅ kapandı | 7 |
| 1 · Temel (API/Postgres+RLS/auth) | %10 | ✅ kapandı | 10 |
| 2 · Offline çekirdek (Drift/outbox/sync) | %13 | ✅ kapandı | 13 |
| 3 · Defter (veresiye/kasa/kupon/gün sonu) | %10 | ✅ kapandı | 10 |
| 4 · Kurye (atama/teslim/kasa devri/+iOS) | %11 | 🔄 ~%92 (API✅ inceleme✅ mobil test✅; iOS açık) | ~10 |
| **4b · Saha UI (bayi+kurye ekranları)** | **%15** | ✅ **KAPANDI** (D1 giriş+kabuk+müşteri · D2 sipariş+teslim+ürün · D3 defter+tahsilat+gün-sonu · D4 kurye+kasa devri) | 15 |
| 5 · Para (site/iyzico/abonelik/panel) | %17 | 🔄 ~%93 KOD TAM (dışsal: anahtar/hukuk) | ~16 |
| 6 · Mağaza + hukuk (Play/KVKK/mesafeli) | %10 | 🔄 ~%22 (demo hesap ✅ + metin paketi ✅ + hesap-silme ✅; kalan dışsal) | ~2 |
| 7 · Antalya pilotu (2–3 bayi) | %7 | ⬜ bekliyor (saha/insan) | 0 |
| **Toplam** | **%100** | | **~%78** |

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
| 4 | Kurye: atama, teslim kapatma, kasa devri (+iOS başlangıcı) | 🔄 **~%92** (API ✅ inceleme ✅ mobil test ✅ 2026-07-17; iOS/gerçek-cihaz açık) |
| 5 | Para: site, iyzico, abonelik kilidi, yönetim paneli | 🔄 **KOD TAM** (sunucu ✅ inceleme ✅ güvenlik ✅ 163/163); dışsal: iyzico anahtar/hukuk prose/mobil |
| 6 | Mağaza+hukuk: Play beyanları, demo hesap, KVKK/mesafeli satış | bekliyor |
| 7 | Antalya pilotu: 2–3 gerçek bayi | bekliyor |

## Güncel durum (son güncelleme: 2026-07-21/3 — 4b Dilim 4 bitti, 4b KAPANDI; kodla yapılabilir iş TÜKENDİ)

### VARDİYA 2026-07-21/3 (4b DİLİM 4 — kurye + kasa devri; 4 ajanlı hat, koordinasyon kazalı ama YEŞİL)

**Kullanıcı talebi:** "plandaki kalan görevlerin hepsini ajanlarla bitir." Hat: **architect** (Plan tipi,
tasarım) → **coder-2** → **tester-2** → **reviewer-2**. Ek görevler: guzzle güvenlik yükseltmesi (4
Dependabot uyarısı) + customer_ledger mağaza-kuralı simetri testi.

### NE BİTTİ (bu vardiya — üç bağımsız doğrulama: tester-2, reviewer-2, lead)
- **4b DİLİM 4 BİTTİ → 4b · Saha UI TAMAMEN KAPANDI:**
  - **Sunucu:** `SyncService::teamPayload` — push/pull yanıtına `team` bloğu (subscription deseni;
    YALNIZ id/name/role/status — parola/telefon/e-posta ASLA; sipario_app bağlantısı = FORCE RLS →
    cross-tenant yapısal imkânsız). `SyncTeamTest` 5 test (cross-tenant sızmaz + PII-asgari kanıtı).
  - **Mobil:** Drift **v7 additif** `users` aynası (senkronda toptan tazelenir; `team=null` → dokunma
    [eski sunucu uyumu], `[]` → temizle); `lib/screens/team.dart` — `yetkiler()` K2 rol matrisi
    (kurye: teslim+tahsilat+kendi kasa devri; yönetici işleri patron/operator; **atama ve kasa devri
    yalnız AKTİF KURYE VARSA** → tek kişilik bayide HİÇ render edilmez — BRIEF pazarlıksız, testli);
    sipariş listesinde kuryeye "Benim" sekmesi + atanmış kurye chip'i; sipariş detayında atama UI;
    `cash_handover_screen.dart` (beklenen nakit `CashHandoverRepository.onizle()` — ekran ve kayıt
    AYNI koddan; sayılan tutar parseKurus; fark KANIT, eksik para kırmızı görünür kalır; düzeltme
    YENİ devirle); home_shell rol/yetki gating.
  - **Guzzle 7.14.0 → 7.15.1** (+psr7): 4 Dependabot uyarısının hepsi kapandı, `composer audit` temiz,
    majör atlama yok, kod değişikliği yok.
- **Doğrulama:** mobil `dart analyze` 0 · `flutter test` **159/159** (~7 sn; 130 taban + 29) · debug
  APK derlendi · izin bekçisi temiz; API `phpunit` **174/174 (608 assert)** · pint ✓ · phpstan sv6 0 ·
  `composer audit` temiz. **İnceleme (reviewer-2): 8 madde dosya:satır kanıtıyla YEŞİL — kırmızı çizgi
  ihlali YOK; en kritik risk (#1 pull'a team eklenmesi) test+kod düzeyinde kanıtlandı.**

### KODLA YAPILABİLİR İŞ BİTTİ — KALAN HER ŞEY DIŞSAL/İNSAN
1. **PR #11 merge** (dev→main; Faz 3–6 + 4b'nin tamamı) — düğme insanda.
2. **Gerçek cihaz doğrulaması** — güncel APK'da artık TAM ürün akışı var: giriş → müşteri → ürün →
   sipariş → teslim → tahsilat → gün sonu → (kurye varsa) atama + kasa devri → arayan tanıma +
   journal_mode/native uyumu. `adb install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
3. **YAPILACAKLAR.md** (kanonik dışsal liste): iyzico anahtarı + verify güvenlik testi, hukuk/avukat,
   mağaza hesapları + release imza anahtarı, Mac/Xcode (iOS), e-arşiv, VERBİS, Antalya pilotu.

### BİLİNEN TUZAKLAR (bu vardiya — YENİ dersler, çoğu AJAN KOORDİNASYONU)
- **Ajan adı çakışması:** aynı adla ikinci ajan spawn edilince yeni ajan `-2` eki alır ama ESKİ ada
  giden SendMessage eski (bitmiş) ajanı DİRİLTİR — bu vardiya eski 'coder' yanlış mesajla Dilim 4'ü
  paralel yazmaya başladı. Ders: her tura TAZE benzersiz adlar ver; yanlış diriltilen ajanı nazik "dur"
  mesajı TUR ORTASINDA durdurmaz — `TaskStop` (sert sonlandırma) gerekir, sonra ağacın gerçekten
  donduğunu mtime taramasıyla doğrula.
- **`Get-Process dart,flutter_tester -ErrorAction Stop` TUZAĞI:** listedeki HERHANGİ bir ad yoksa
  istisna fırlar ve VAR OLAN süreçler de gizlenir (bu vardiya iki zombi flutter_tester bu yüzden
  görünmedi, sqlite3.dll kilidi 3 koşum yaktı). Süreçleri AYRI AYRI sorgula.
- **Kilitli `build/native_assets/.../sqlite3.dll`:** `rm -rf` sessizce başarısız olur (kabuk asılır);
  önce dll'i tutan süreci bul (`Get-Process | ? { $_.Modules.FileName -eq $yol }`), öldür, sonra sil.
- **`addTearDown(db.close)` widget testinde YİNE yazıldı** (Dilim 1 dersi tekrar yaşandı — bu kez
  eski-coder'ın test dosyasında): akış-abonelikli drift db widget-test zonunda kapatılMAZ; shrink
  sonrası `pump(Duration(seconds: 5))` şart (!timersPending). Test dosyasının başına açıklama kondu.
- **Ajan sessiz ölebilir:** coder-2 doğrulama aşamasında yanıtsız kaldı (dürtme dahil) — kalan işi
  lead devraldı. Ders: teslim mesajı gelmeden "bitti" sayma; ağaç + süreç durumundan gerçeği oku.


### VARDİYA 2026-07-21/2 (4b DİLİM 3 — 4 AJANLI HAT: auditor→coder→tester→reviewer)

**Kullanıcı talebi:** "yapılmış görevleri analiz et, eksikleri ajanlarla tamamla." Sıralı hat kuruldu
(hepsi aynı dev ağacında — worktree yasak; inceleme donmuş ağaçta): **auditor** (salt-okunur denetim +
repo imza çıkarımı) → **coder** (Dilim 3 ekranları) → **tester** (9 ek derinleştirme testi) →
**reviewer** (8 maddelik kırmızı-çizgi incelemesi + bağımsız koşum). Lead ayrıca bağımsız doğruladı.

### NE BİTTİ (bu vardiya — commit a90b70f + b0fa8ec, otomatik kalite-kapısı hook'u commit'ledi)
- **4b DİLİM 3 BİTTİ — defter/tahsilat/gün-sonu ekranda:**
  - `lib/screens/customers/customer_ledger.dart` (417 satır, YENİ) — müşteri detayına defter bölümü:
    hareket listesi (entry_type/payment_type Türkçe etiketli, imzalı renkli tutar), **"Tahsilat al"**
    (parseKurus + nakit/kart/havale → LedgerRepository), **"Kupon sat"** (adet + not → CouponRepository;
    eksi bakiye kırmızı ama hiçbir işlem engellenmez), **"Ters kayıtla düzelt"** (satır menüsünden;
    yalnız ters kayıt — silme/ezme YOK, salt-okunurda menü hiç render edilmez).
  - `lib/screens/day_end_screen.dart` (218 satır, YENİ) — Menü → **"Gün sonu"**: kasa özeti ödeme tipi
    bazında + veresiye toplamı + kupon özeti (DayEndRepository read-model, TAMAMEN salt-okunur).
  - `customer_detail_screen.dart` +9 (CustomerLedgerSection entegre; dosya 500 sınırının altında
    kalsın diye defter ayrı dosyada), `home_shell.dart` +9 (Gün sonu menü girişi).
  - `test/ui_dilim3_test.dart` (498 satır): coder 12 + tester 9 = 21 test. Öne çıkanlar: **append-only
    kanıtı** (düzeltme sonrası satır sayısı +1 VE orijinal satır drift value-equality ile birebir
    değişmemiş), tahsilatın bakiye+kasayı AYNI tutarda değiştirmesi, kupon zinciri (sat→düş→eksiye düş),
    gün-sonu rakamlarının ELLE kurulan beklentiyle karşılaştırılması, salt-okunur kapı kontrastları,
    ekran-repo tutarlılığı (12345 kuruş → "+123,45 ₺").
- **İNCELEME: YEŞİL (reviewer, bağımsız koşumla).** 8 madde kod kanıtıyla: append-only ✓ para-int-kuruş ✓
  mağaza kuralı ✓ KVKK (sıfır log) ✓ salt-okunur kip ✓ offline-first ✓ kalite (<500, ekran-dışı sorgular) ✓
  ekran-defter tutarlılığı ✓. Repository'lere DOKUNULMADI (Faz 3'te incelenmişlerdi; Dilim 3 yalnız delege eder).
- **Doğrulama (üç bağımsız koşum: tester, reviewer, lead):** `dart analyze` 0 · `flutter test`
  **130/130 (~6 sn)** · debug APK derlendi · `check_permissions_source.sh` temiz.

### NE YARIM KALDI / AÇIK
- **Dilim 4 (son UI dilimi): kurye ekranları + kasa devri** — atama (assign/unassign repoda hazır),
  kurye görünümü, kasa devri (`CashHandoverRepository` hazır). **Tek kişilik bayide kurye adımları
  HİÇ GÖRÜNMEZ (BRIEF)** — kullanıcı listesi/rol bilgisi üzerinden koşullanacak.
- **Reviewer'ın minör gözlemi (bloklamaz):** customer_ledger için ayrı mağaza-kuralı regresyon testi yok
  (day_end ve orders'ta var; ekran yalnız iş ₺'si gösteriyor, ihlal değil) — simetri için eklenebilir.
- Gerçek cihaz doğrulaması + PR #11 merge + dışsal işler (YAPILACAKLAR.md) — değişmedi, insanda.

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. **Sıradaki kod işi = Dilim 4: kurye + kasa devri** (son UI dilimi; desen aynı). Tek kişilik bayi
   gizleme kuralına dikkat.
2. **Telefon bağlanırsa öncelik:** gerçek cihaz doğrulaması (Dilim 1-2-3'lü APK hazır:
   `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`) — giriş → müşteri → ürün → sipariş →
   teslim → tahsilat → gün sonu → arayan tanıma → journal_mode/native uyumu.
3. PR #11 merge insanda; dışsal işler `YAPILACAKLAR.md`.

### BİLİNEN TUZAKLAR (bu vardiya — YENİ ders)
- **Widget-testin sahte-zaman diliminde HERHANGİ gerçek async drift çağrısı asılır — yalnız watch()
  değil, DÜZ Future sorgular da** (`getSingle()`, `.first`): `tester.runAsync(() async {...})` sarmalı
  ŞART. Dilim 1 dersinin genişletilmiş hali; tester bunu 6 dk asılı koşumla yaşadı (normal koşum ~6 sn —
  koşum dakikalara uzuyorsa asılı test var demektir, 10 dk timeout'u bekleme).
- Asılı `flutter test` öldürünce yetim süreç temizliği: `Get-Process dart,flutter_tester | Stop-Process -Force`
  (sqlite3.dll kilidi sonraki build'i kırar — Dilim 1'den beri geçerli).
- **Stop hook'u ajan oturumlarının sonunda otomatik commit + push yaptı** (a90b70f, b0fa8ec —
  "otomatik(dev)" mesajlı). Ajanlara "commit yapma" dense de hook devrede; kapanışta `git log`'a bak,
  işin zaten commit'lenmiş olabilir.

### VARDİYA 2026-07-21 (4b DİLİM 2 — sipariş ekranları; İKİNCİ GELİŞTİRİCİ MAKİNESİ)

**Bu vardiya `C:\Users\GokhanT\Desktop\sipario` makinesinde koştu** (diğer geliştiricininki
`C:\Users\bugra\OneDrive\Masaüstü\...`). **Önemli fark: bu makinede yol ASCII** — geçen vardiyanın
"Türkçe-yol tuzakları" (build_runner `--force-jit`, `flutter analyze` LSP çökmesi, AGP ASCII reddi)
BURADA YAŞANMADI; `flutter analyze`/`dart analyze` ve normal build sorunsuz. Flutter `C:\flutter`'da,
php Laragon'da PATH'te, Docker/Postgres ayakta DEĞİL (mobil iş için gerekmedi).

### NE BİTTİ (bu vardiya — hepsi bu makinede koşulup doğrulandı)
- **4b DİLİM 2 BİTTİ — sipariş akışı uçtan uca ekranda:**
  - `lib/screens/orders/order_list_screen.dart` — Açık/Teslim/Tümü sekmeli liste (`watchOrders()`
    ekrandan ayrı, müşteri adı LEFT JOIN, en yeni önce), durum ikonu, tutar, salt-okunur FAB kapısı.
  - `lib/screens/orders/order_form_screen.dart` — yeni sipariş: müşteri seçici (Dilim 1'in son-10
    telefon arama kuralını AYNEN kullanır), katalogdan ürün ekleme (aynı ürün ikinci kez seçilince
    adet artar), **serbest satır** (katalogda olmayan tek seferlik iş; ürün kaydı OLUŞTURMAZ),
    adet ±, canlı toplam, not. **Ödeme tipi BURADA sorulmaz** — teslimde sorulur.
  - `lib/screens/orders/order_detail_screen.dart` — satırlar/toplam/durum + **teslim kapatma**
    (`OrderRepository.deliver`) ve iptal. Ödeme tipi alt sayfası: nakit/kart/havale + **müşteri
    varsa** veresiye/kupon. Kuponda "N adet düşer · kalan M" gösterilir, M<0 kırmızıdır ama
    **teslim REDDEDİLMEZ** (BRIEF: teslim edilmiş mal gerçektir).
  - `lib/screens/products/product_list_screen.dart` — Menü → **Ürünler** (ekle/düzenle/pasifle).
    Gerekçe: taze kurulumda bayinin hiç ürünü yok, sipariş ekranı onsuz kullanılamazdı (ürünler
    senkronla da gelir ama ilk ürünü birinin girmesi gerek). Silme yok, PASİFLEME var.
  - `lib/screens/money.dart` — `formatKurus` (customer_list'ten taşındı) + **yeni `parseKurus`**:
    kullanıcı yazımı ↔ int kuruş sınırı tek yerde. "1.234" TR binlik sayılır; 2 haneden uzun kuruş
    REDDEDİLİR (sessiz yuvarlama yok — para).
  - `home_shell` `_OrdersPlaceholder` KALDIRILDI → gerçek sipariş sekmesi; Menü'ye Ürünler eklendi.
  - Müşteri detayına **"Sipariş oluştur"** düğmesi (telefon çaldı → kart açıldı → sipariş: BRIEF'in
    "birkaç dokunuş" akışı).
- **Doğrulama: `dart analyze` 0 sorun · `flutter test` 109/109 (89 → +20) · debug APK derlendi ·
  `check_permissions_source.sh` temiz (kırmızı çizgi #6 bekçisi).**
- **Yeni testler (`test/ui_dilim2_test.dart`):** parseKurus (TR yazımları + gidiş-dönüş + red
  edilenler), toplamKurus, `teslimOdemeTipleri` (müşterisiz siparişte veresiye/kupon SUNULMAZ),
  saatBicimi, watchProducts (aktif/pasif), watchOrders (3 filtre + join + sıra), **`kuponAdedi`
  ekranla defteri aynı sayıda tutuyor mu** (ekran 5 diyorsa defter −5 yazmalı; eksi bakiye kabul),
  OrderList/ProductList salt-okunur kapıları, sipariş ekranında mağaza-kuralı regresyonu.

### NE YARIM KALDI / AÇIK (bu vardiya)
- **Dilim 3 (sıradaki kod işi): defter/tahsilat/gün-sonu ekranları** — `LedgerRepository`
  (tahsilat/borç/alacak/düzeltme), `CouponRepository` (kupon satışı), `DayEndRepository` (kasa/borç/
  kupon salt-okuma) HAZIR bekliyor; müşteri detayında hareket listesi + "Tahsilat al" ve Menü'de
  "Gün sonu" ekranı gelecek. Sonra Dilim 4 (kurye + kasa devri; tek kişilik bayide GİZLİ).
- **Sipariş düzenleme (satır ekle/çıkar) ekranda YOK** — `addLine`/`removeLine`/`setNote` repoda var;
  bilinçli sadelik: açık sipariş yanlışsa iptal edilip yeniden girilir. Saha isterse Dilim 3'e eklenir.
- **Gerçek cihaz doğrulaması HÂLÂ yapılmadı** (geçen vardiyadan devir): arayan tanıma + Drift v6
  `journal_mode=TRUNCATE`'in native salt-okunur açıcıyla uyumu CİHAZDA görülmedi.
- **PR #11 merge insanda** (artık Dilim 2 commit'leri de dahil). Dışsal işler `YAPILACAKLAR.md`.

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. **Sıradaki kod işi = Dilim 3: defter/tahsilat/gün sonu ekranları** (desen aynı: ekran → var olan
   repository → ekrandan ayrı `watch*()` sorgusu → saf async test + widget ilk-çizim testi → APK).
2. **Telefon bağlanırsa öncelik:** `adb install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`
   → giriş → müşteri ekle → ürün ekle → sipariş gir → teslim et → o numaradan ara (kart çıkmalı) →
   journal_mode/native uyumu. Giriş için API telefondan erişilebilir olmalı (aşağıdaki tuzak).
3. PR #11 merge insanda; dışsal işler `YAPILACAKLAR.md`.

### BİLİNEN TUZAKLAR (bu vardiya)
- **İki geliştirici makinesi FARKLI davranıyor:** Türkçe-yol tuzakları yalnız `Masaüstü` yollu
  makinede geçerli; ASCII yollu makinede `flutter analyze` ve normal `build_runner` çalışır.
  Komut sırasını makineye göre seç, "geçen vardiyada böyleydi" diye körlemesine uygulama.
- **`Order` sınıfı Drift'ten gelir** (`Orders` tablosunun satır sınıfı); `drift.dart`'ı material ile
  birlikte import ederken `hide Column` şart (mevcut desen).
- **Testte `Expression<bool>` üzerinde `&` kullanmak drift import'u ister** — ya `hide Column, Table`
  ile import et ya da (tercih) `..where()..where()` zincirle (drift AND'ler).
- **uuid7 aynı milisaniyede monoton değil** — sıralama testi yazarken kayıtlar arasına birkaç ms
  bekleme koy, `occurred_at` ayrışsın (id yalnız eşitlik bozucudur).

### VARDİYA 2026-07-17/2 (Flutter kurulumu + mobil doğrulama + pano düzeltmesi + 4b DİLİM 1)

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
- **4b DİLİM 1 BİTTİ (aynı vardiya, commit `94a2f4a`):** giriş/oturum (`lib/auth/` — token sync_meta'da,
  deviceId ilk girişte üretilip KALICI, çıkış veri silmez), senkron servisi (`lib/sync/sync_service.dart` —
  periyodik 2 dk push+pull + durum akışı), ekranlar (`lib/screens/` — login mağaza-kuralı temiz [kayıt/
  fiyat/₺ YOK, regresyon testli], home_shell 3 sekme + abonelik şeridi + salt-okunur kapısı, müşteri
  liste/arama/ekle/detay). Drift şema v6 (additif). **Doğrulama: dart analyze 0 · flutter test 89/89 ·
  APK derlendi.** Testin bulduğu GERÇEK hata: '0532...' yazımı telefon aramasında eşleşmiyordu → normalize
  düzeltildi. Faz 0 ölçüm ekranı üründe KALDI (Menü → arayan tanıma).
- **Kullanıcıya Dilim 1'li APK teslim edildi** (`apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`);
  demo hesap `demo@sipario.com.tr / demo1234` (sunucuda DemoSeeder ile).

### NE YARIM KALDI / AÇIK
- **4b'nin kalan dilimleri (sıradaki kod işi):** Dilim 2 sipariş ekranları (yeni sipariş, açık liste,
  teslim kapatma — `OrderRepository.deliver` hazır bekliyor) → Dilim 3 tahsilat/defter/gün-sonu →
  Dilim 4 kurye+kasa devri (tek kişilik bayide kurye adımları GİZLİ — BRIEF).
- **Gerçek cihaz doğrulaması yapılmadı:** kullanıcı APK'yı telefonda henüz denemedi (vardiya kapanırken
  bekliyordu). Telefon gelince: `adb install -r` → giriş → müşteri ekle → o numaradan ara → kart çıkmalı.
  Aynı seansta **Drift v6 + journal_mode=TRUNCATE'in native salt-okunur açıcıyla uyumu** cihazda sınanmalı
  (Faz 2'den beri açık risk; şema v6'ya büyüdü, native sözleşme korunuyor ama CİHAZDA görülmedi).
- **PR #11 merge bekliyor** (Faz 3+4+5+6 → main; bugünkü Dilim 1 commit'leri de PR'a dahil — dal dev).
  Kullanıcıya "merge düğmesi"nin ne olduğu anlatıldı; hazır olduğunda basacak (veya "merge et" diyecek).
- **Dışsal işler** `YAPILACAKLAR.md` (madde 2 KAPANDI; iyzico/avukat/imza-anahtarı/mağaza/pilot duruyor).

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. **Sıradaki kod işi = Dilim 2: sipariş ekranları.** Yeni sipariş (müşteri seç + ürün satırları — ürünler
   sync'le geliyor, `ProductRepository` hazır), açık sipariş listesi, teslim kapatma (ödeme tipi
   peşin/veresiye/kupon — `OrderRepository.deliver` para+kupon defterini zaten yazıyor). Home_shell'deki
   `_OrdersPlaceholder`'ın yerine gelecek. Desen Dilim 1'dekiyle aynı: ekran → repository → test → APK.
2. **Kullanıcı telefonu bağlarsa (öncelik):** `adb install -r apps/mobile/build/.../app-debug.apk` →
   gerçek cihazda giriş + müşteri + arayan-tanıma + **journal_mode/native uyum** doğrulaması (yukarıda).
   Giriş için API'nin telefondan erişilebilir olması gerek — aşağıdaki tuzağa bak.
3. PR #11 merge insanda; dışsal işler `YAPILACAKLAR.md`.

### BİLİNEN TUZAKLAR (bu vardiya — sonraki kişi dikkat)
- **Mobil komut sırası (bu makine):** kısa yola cd (`/c/Users/bugra/OneDrive/MASAST~1/...`) güvenli;
  codegen `--force-jit` ŞART; analiz `dart analyze` (flutter analyze ÇÖKÜYOR, kapı scripti de dart analyze koşar).
  Tam sıra hafıza dosyasında ve DECISIONS "Türkçe-yol" satırında.
- **Drift + widget-test üç dersi (DECISIONS'a işlendi):** akış-zamanlamalı senaryoyu saf async teste indir
  (`watchCustomers()` bu yüzden ekrandan ayrı); akış-abonelikli db'yi widget-testte `close()` ETME (asılı
  kalıyor); test sonunda ağacı boşaltıp sahte saati ilerlet (bekleyen SnackBar/animasyon sayaçları).
- **Takılan `flutter test`'i öldürünce dart süreçleri yetim kalıyor** ve `build/native_assets/.../sqlite3.dll`
  kilitli kalıp SONRAKİ build'i "cannot access file" ile kırıyor → `Get-Process dart,flutter_tester | Stop-Process -Force`.
- **Telefonda GERÇEK giriş için API'ye erişim gerek:** sunucu şu an yalnız bu makinede. Telefon aynı
  Wi-Fi'deyken `php artisan serve --host 0.0.0.0 --port 8000` ile başlat, telefonda login "Gelişmiş" →
  `http://<PC-yerel-IP>:8000/api/v1`. (Mobil bearer kullanır, CORS tarayıcı işi — engel değil.)
- **`flutter build apk` ilk koşuda uzun** (Gradle+CMake indirir, ~5-8 dk); sonrakiler saniyeler-dakikalar.
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
