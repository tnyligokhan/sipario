# Google Play — Veri Güvenliği (Data Safety) Formu Taslağı

⚠️ **TASLAK** — mağaza konsoluna girmeden önce gerçek şirket bilgisi + video + insan kontrolü gerekir.

Bu belge, Play Console → "Uygulama içeriği" → "Veri güvenliği" formunun soru sırasını izler.
Konsoldaki soru metinleri Google tarafından zaman zaman güncellenir; girerken bu taslağı
karşılaştırarak doldur, kelimesi kelimesine kopyalama.

## 1. Genel sorular

| Soru | Cevap |
|---|---|
| Uygulama veri topluyor mu? | **Evet** |
| Uygulama veri paylaşıyor mu? | **Evet** (yalnız zorunlu altyapı sağlayıcılarıyla — aşağıda) |
| Veri aktarımı şifrelenmiş mi? (uçuş halinde) | **Evet** — tüm API trafiği TLS ile |
| Kullanıcı veri silinmesini talep edebilir mi? | **Evet** — uygulama içinde silme düğmesi YOK (bilinçli tasarım, BRIEF §4: veri bayinin
mülkiyetindedir, kayıt dışsal süreçle kapanır); talep **destek kanalı** üzerinden yapılır → `[destek e-postası/URL — PLACEHOLDER]`. Bu hesap oluşturma web sitesi üzerinden yürüdüğü için Play'in hesap-silme politikası gereği ayrıca bir **web sayfası** da gerekebilir — `[hesap silme sayfası URL — PLACEHOLDER, henüz yok]`. |

## 2. Toplanan / paylaşılan veri türleri

Kaynak: bayi (patron/operatör) uygulamaya kendi müşterisinin bilgisini girer; uygulama
kendiliğinden üçüncü taraf reklam/analitik SDK'sı **içermez** (bkz. `apps/mobile/pubspec.yaml`
— Faz 6 itibarıyla Firebase/Sentry/analitik paketi yok). Aşağıdaki tablo yalnız gerçekten
var olan alanları listeler.

| Kategori | Veri | Toplanıyor mu | Paylaşılıyor mu | Amaç | Zorunlu/opsiyonel |
|---|---|---|---|---|---|
| Kişisel bilgiler | Ad soyad (müşteri) | Evet | Hayır (yalnız kendi sunucumuz) | Uygulama işlevselliği (sipariş/veresiye kaydı) | Zorunlu |
| Kişisel bilgiler | Telefon numarası (müşteri) | Evet | Hayır | Uygulama işlevselliği + arayan tanıma | Zorunlu |
| Kişisel bilgiler | Fiziksel adres (müşteri) | Evet | Hayır | Uygulama işlevselliği (teslimat) | Opsiyonel (adressiz müşteri olabilir) |
| Kişisel bilgiler | E-posta + şifre (bayi kullanıcı hesabı) | Evet | Hayır | Hesap kimlik doğrulama | Zorunlu |
| Konum | Yaklaşık/kesin konum | Evet (yalnız teslimat anında, best-effort) | Hayır | Kurye teslimat kaydı | Opsiyonel — BRIEF: "konum alınamıyorsa teslim ASLA bloklanmaz" |
| Finansal bilgiler | Sipariş tutarı / veresiye bakiyesi / ödeme tipi | Evet | Hayır | Uygulama işlevselliği (defter) | Zorunlu |
| Cihaz veya diğer kimlikler | Cihaz kaydı (senkron için istemci üretimli kimlik) | Evet | Hayır | Çoklu cihaz senkronizasyonu, hesap güvenliği | Zorunlu |
| Kişiler (Contacts) | Rehber verisi | **Toplanmıyor / sunucuya gönderilmiyor** | Hayır | — | — |

### "Kişiler" kategorisi için özel not — `READ_CONTACTS`

Uygulama `READ_CONTACTS` iznini talep eder ama rehberi **taramaz, yüklemez, sunucuya
göndermez.** İzin yalnız Android'in `CallScreeningService` API'sinin, rehberde KAYITLI bir
numara aradığında dahi çağrıyı uygulamaya bildirebilmesi için sistem tarafından şart koşulan
bir ön koşuldur (bkz. `apps/mobile/android/app/src/main/AndroidManifest.xml` yorumu ve
DECISIONS "Arayan tanıma (Faz 0)"). Numara, o anki çağrı anında `Call.Details.getHandle()`
ile anlık okunur, cihazdan çıkmaz. Play formunda bu kategori için "toplanmıyor" seçilecek;
gerekirse "İzin var ama veri toplanmıyor" açıklama kutusuna yukarıdaki paragraf özetlenecek.

## 3. Üçüncü taraflarla paylaşım

| Alıcı | Hangi veri | Neden |
|---|---|---|
| Sipario sunucusu (kendi altyapımız, **Türkiye'de barındırılır** — BRIEF kırmızı çizgi #4) | Yukarıdaki tüm kategoriler | Uygulamanın çalışması için zorunlu birinci taraf işleme; "paylaşım" değil ama Play formu birinci taraf sunucuyu da bazı sorularda ayrı sayabiliyor — doldururken güncel form diline bak |
| iyzico (ödeme altyapısı) | — **mobil uygulama bu veriyi işlemez** | Abonelik/ödeme yalnız **web sitesinde** yürür (BRIEF §4, kırmızı çizgi mağaza kuralı); kart bilgisi hiçbir zaman Sipario sunucusuna ya da mobil uygulamaya değmez. Play formunda bu satır YOK sayılmalı çünkü uygulamanın kendisi ödeme akışına girmiyor. |

## 4. Güvenlik uygulamaları

- Veriler aktarımda (in transit) şifrelenir — **Evet** (TLS).
- Veriler saklamada (at rest) şifrelenir — `[sunucu disk şifrelemesi — altyapı sağlayıcısına göre PLACEHOLDER, doğrulanacak]`.
- Kullanıcılar veri silinmesini talep edebilir — **Evet**, yukarıdaki 1. bölümdeki destek kanalı.
- Şirket bir bağımsız güvenlik incelemesinden geçti mi (App Defense Alliance vb.) — `[PLACEHOLDER — henüz yok]`, "Hayır" işaretlenebilir.

## 5. KVKK bağlantısı

Bu form Google'ın kendi kategorileriyle sınırlı; KVKK aydınlatma metninin tam içeriği
`apps/api/resources/views/legal/` altındaki 5d iskeletinde. İki belge arasında tutarsızlık
olmamalı (örn. burada "silme yalnız destek kanalı" derken KVKK metninde farklı bir süreç
tarif edilmemeli) — bu tutarlılık kontrolü `legal-reviewer`'ın işi.
