# DECISIONS.md — Sipario

Her satır bir karar ve tek cümlelik gerekçesi. Yeni kararlar sona eklenir, eskiler silinmez;
değişen bir karar "~~üstü çizili~~ → yeni karar" biçiminde güncellenir.

## Stack

- **Mobil: Flutter + native Kotlin köprüsü** — ekipte Flutter deneyimi var, tek kod tabanı Android+iOS; arayan tanıma zaten native yazılacağı için Flutter engel değil.
- ~~API: Laravel 12 / PHP 8.3~~ → **API: Laravel 13 / PHP 8.3** — iskelet oluşturulduğunda güncel major 13'tü (kurulu: v13.19.0); karar yazıldığındaki "12" o günün güncel sürümüydü, niyet "güncel Laravel + PHP 8.3"tür; gerekçe değişmedi (ekip deneyimi + bakım maliyeti).
- **Veritabanı: PostgreSQL 16** — Row-Level Security ile kiracı izolasyonu veritabanı seviyesinde zorlanabiliyor (kırmızı çizgi #1); MySQL'de bu yok.
- **Yerel DB: SQLite (Drift)** — offline asıl üründür, Drift tip güvenli sorgu ve migration disiplini verir.
- **Site + yönetim paneli: Laravel + Livewire, aynı repo ayrı guard** — v1'de ayrı frontend'in maliyeti karşılığını vermiyor.
- **Ödeme: iyzico** — TR yerleşik (KVKK/veri yerleşimi), kart saklama + abonelik API'si olgun; PayTR'nin yinelenen tahsilatı zayıf, Craftgate bu ölçekte pahalı.
- **Sunucu: Türkiye'de barındırılan VPS + Docker** — kırmızı çizgi #4; Hetzner/DO/Firebase bu yüzden eleniyor.
- **Hazır senkron motoru (PowerSync/Realm) kullanılmayacak** — defterin çakışma kuralları bize özgü, kara kutuya emanet edilmez.

## Veri modeli

- **Para ve hareket kayıtları append-only (`ledger_entries`)** — kırmızı çizgi #2; silme/güncelleme yok, düzeltme yalnız ters kayıtla.
- **Bakiyenin doğruluk kaynağı defterdir; `customers.balance_kurus` yalnız bir okuma-modeli önbelleğidir** — arayan tanımanın 1 sn bütçesinde native taraf toplama yapamaz, tek satır okur; önbellek her defter yazımında tazelenir ve bozulursa defterden yeniden kurulur.
- **Para her yerde kuruş cinsinden tam sayı** — kayan noktalı sayı esnafın defteriyle kuruş farkı üretir, ürüne güven ölür.
- **Kimlikler UUIDv7 ve istemcide üretilir** — offline oluşturulan kaydın id'si sunucuya çıkınca değişmez, referanslar kırılmaz, senkron sırası önemsizleşir.
- **`customer_phones` ve `customer_addresses` ayrı tablolar** — müşterinin ev+cep numarası, ev+işyeri adresi olur; tek sütun 1NF ihlaliydi ve arayan tanımayı ikinci numarada kör bırakıyordu.
- **`tenant_id` her tabloda tekrarlanır (bilinçli 3NF sapması)** — RLS politikası her tabloda join'siz çalışsın diye; tutarlılık `(tenant_id, parent_id)` bileşik yabancı anahtarıyla veritabanı seviyesinde zorlanır.
- **`order_lines.unit_price` ve `product_name` satırda saklanır** — denormalizasyon değil: satırdaki fiyat ürünün bugünkü fiyatının fonksiyonu değil, siparişin çekildiği andaki gerçeğidir.
- **`orders.status` bir önbellek sütunudur, kaynak `order_events`** — sorgu kolaylığı için tutulur, doğruluğun kaynağı olay tablosudur.
- **Kupon bakiyesi eksiye düşebilir** — teslim edilmiş mal gerçektir, sistem reddedemez; UI kırmızı gösterir, düzeltme kaydıyla kapatılır.

## Senkron

- **Yazma yolu outbox üzerinden** — uygulama asla doğrudan API'ye yazmaz; yerel SQLite + outbox aynı işlemde yazılır, arka plan işçisi gönderir.
- **Her olayda `client_event_id`, sunucuda tenant içi tekil** — retry her zaman güvenlidir, "gönderdim mi acaba" durumu oluşmaz.
- **Okuma yolu tenant başına monoton `sequence` ile delta pull** — ilk kurulumda tam snapshot.
- **Defter kayıtlarında çakışma yoktur, birleşme vardır** — iki cihaz aynı anda yazdıysa iki kayıt da geçerlidir.
- **Varlık alanlarında (ad, adres) son yazan kazanır, eşitlikte `device_id` ile deterministik ayrım** — adres para değildir, kaybı tolere edilebilir.
- **Sunucu her yanıtta kendi saatini döner, istemci offset tutar** — esnafın telefon saati yanlış olabilir, `occurred_at` düzeltilmiş saatle yazılır.

## Abonelik ve kilit

- ~~72 saat sunucuyla konuşulamazsa salt-okunur~~ → **`valid_until` tarihi + 7 gün lütuf süresi** — "N saat sessizlik" kuralı bizim sunucu kesintimizi ödeyen bayinin cezasına çeviriyordu; istemci abonelik bitiş tarihini zaten biliyor, uçak modu açığı tarihle kapanır.
- **`valid_until` gelecekteyken cihaz sunucuyla haftalarca konuşamasa da tam çalışır** — fatura ödenmiştir, kilitlemek için sebep yok.
- **`valid_until` geçmişse ve sunucuya sorulamıyorsa 7 gün lütuf, sonra salt-okunur** — ödeyen bayiyi yanlışlıkla kilitlemenin maliyeti, ödemeyene bir hafta fazladan kullandırmanın maliyetinden kat kat büyük.
- **Cihazda ileri-sadece saat (`elapsedRealtime` + son görülen sunucu zamanı)** — kullanıcı sistem saatini geri alarak lütuf süresini uzatamaz.
- **Kilitliyken outbox akmaya devam eder; sunucu `occurred_at <= locked_at` olanları kabul eder** — kilit yazmayı durdurur, veri kaybettirmez (kırmızı çizgi #5).

## Faz 0 kapanışı

- **Faz 0 kararı: GO (şartlı) — 2026-07-10** — iki gerçek cihazda (Samsung S24 FE/And.16, Xiaomi 14/HyperOS 2) soğuk süreç, kilitli ekran, derin Doze, rehberli numara, giden arama ve sıfır kurulum uçtan uca kanıtlandı; yasaklı izin sıfır.
- **20 aramalık sistematik tur kullanıcı kararıyla iptal; doğrulama pilotun ilk haftasına devredildi** — kapsamlı ad-hoc test mevcut, ölçüm ekranı üründe kalıyor, pilottaki gerçek aramalar sayacı dolduracak.
- **Xiaomi derin Doze'da zil anı kartı ~2,2 sn (tek bütçe aşımı) — kabul edildi** — gecikmenin tamamı sistemin Doze'dan uyanması (sorgu 5 ms); yanıt anındaki kart 419 ms; bayi telefonu cebinden çıkarana kadar süre zaten geçiyor. MIUI'nin SmartPower'ı ölü süreci kendisi diriltiyor (loglandı) — Doze korkusu kapandı.
- **Stok Android gerçek cihazda test edilmedi** — emülatör (API 34) yazılım yolunu doğruladı; pilot Xiaomi/Samsung ağırlıklı, risk düşük, açık kayıt edildi.

## Faz 1

- ~~Yerel geliştirme veritabanı: taşınabilir PostgreSQL zip'i, Docker yok~~ → **Yerelde de Docker (kullanıcı Docker Desktop'ı kendisi kurdu)** — yerel ile üretim aynı Postgres 16 imajını koşar, "bende çalışıyordu" sınıfı fark ortadan kalkar.

## Çalışma disiplini

- **Otomatik commit disiplini Claude Code Stop hook'u ile (`scripts/quality-gate-commit.ps1`)** — anlamlı iş bitince kalite kapısı (flutter analyze+test, pint, phpstan, php test, sır taraması) yeşilse dev'e otomatik commit+push; main/master'a asla; kapı kırmızıysa commit yok; araç kurulu değilse kontrol atlanır ama commit gövdesine "atlanan" olarak yazılır — çalışmamış kontrol başarılı sayılmaz. Hook harness tarafından çalıştırılır, modelin unutmasından etkilenmez.

## Kiracı izolasyonu

- **PostgreSQL RLS + her istekte `SET LOCAL app.tenant_id`** — değişken set edilmemişse sorgu sıfır satır döner; güvenli varsayılan.
- **Yönetim paneli iş verisi tablolarına yalnız SELECT yetkisi olan ayrı DB rolü kullanır** — panelin bayinin siparişini değiştirememesi kod disiplinine değil, veritabanı iznine bağlı.
- **CI'da cross-tenant test matrisi zorunlu** — yeni endpoint bu testi almadıysa build kırılır; kırmızı çizgi #1'in "sürekli kanıtla" şartı bu.

## Arayan tanıma (Faz 0)

- **Yalnız `CallScreeningService` + `RoleManager.ROLE_CALL_SCREENING`** — kırmızı çizgi #6; SMS/Call Log izin grubundan hiçbir izin alınmaz, numara `Call.Details.getHandle()` ile izinsiz gelir.
- **Overlay tamamen native Kotlin, Flutter engine hiç başlatılmaz** — telefon çaldığında süreç çoğu zaman ölüdür; soğuk Flutter engine 1–2 sn alır ve ≤1 sn hedefi daha başlamadan kaybedilir.
- **Native taraf Drift'in SQLite dosyasını doğrudan salt-okunur açar** — ağ yok, kanal yok; sorgu telefon indeksinden tek okumadır.
- **`SYSTEM_ALERT_WINDOW` ile overlay (birincil), heads-up notification (yedek)** — bu izin Play'in kısıtlı SMS/Call Log grubunda değildir, kırmızı çizgi #6'yı ihlal etmez.
- **`applicationId = com.sipario.app`** — mağazada bir daha değişmez, marka ile hizalı.
- **Manifest izin denetimi CI'da merged manifest üzerinde çalışır** — üçüncü parti paketlerin manifest'e enjekte ettiği izinler ancak birleştirilmiş çıktıda görünür.
- **`minSdk = 29` (Android 10)** — `CallScreeningService` bu sürümle geldi; arayan tanıma ürünün varlık sebebi olduğundan altındaki sürümü desteklemenin anlamı yok.
- **`respondToCall` tanımadan ÖNCE çağrılır** — sistem yanıtı beklerken çağrıyı tutar; sorgu için beklersek zil gecikir ve kullanıcı çağrıyı kaçırır.
- **Numara eşleşmesi son 10 hane üzerinden (`phone_last10`, indeksli)** — +905321112233 / 05321112233 / 5321112233 aynı numaradır ve son 10 hane ülke içinde tekildir.
- **Ölçüm loglarına telefon numarası veya müşteri adı yazılmaz** — kırmızı çizgi #4; yalnız gecikme, eşleşme var/yok ve kullanılan yol tutulur.
- **Simüle çağrılar go/no-go sayımına girmez** — süreç zaten ayakta olduğu için soğuk başlangıç maliyetini hiç ödemez, sahadaki asıl zorluğu ölçmez.
- **Tek kaçırılan çağrı veya tek geç kart NO-GO sayılır** — bayi telefonu açtığında ekranda müşteri yoksa ürünün vaadi çökmüştür; ortalama değil, en kötü durum yönetilir.
- **İzin denetim scripti pozitif kontrolle doğrulanır** — bilerek enjekte edilen bir ihlali yakalayamayan denetim, yeşil yanan bir yalandır.
- **Arayan kartı ekranın ORTASINA çizilir, üstüne değil** — emülatörde görüldü: üstte sistemin heads-up çağrı bildirimi kartın tam olarak müşteri adı ve borç satırlarını örtüyordu; altta da tam ekran çağrı arayüzünün Cevapla/Reddet düğmeleri var.
- **Emülatör sonucu go/no-go SAYILMAZ** — yazılım yolunu (rol, servis, soğuk başlangıç, sorgu, çizim) kanıtlar; korku #1'in asıl konusu olan OEM pil yönetimi ancak gerçek Xiaomi/Samsung cihazda sınanır.
- **`READ_CONTACTS` izni alınır — rehberi okumak için değil, çağrıyı görebilmek için** — Telecom'un `CallScreeningServiceFilter.startFilterLookup()` kodu `if (contactExists && !hasReadContactsPermission()) { servisi atla }` der; izin olmadan bayinin rehberine kaydettiği müşteri aradığında `onScreenCall` HİÇ çağrılmaz. Samsung SM-S721B / Android 16'da doğrulandı: izinsizken kart çıkmadı, izinle birlikte "contact exists" olan çağrıda da `SCREENING_BOUND` alındı ve kart 12 ms'de çizildi.
- **`READ_CONTACTS` bağımlılığı belgelenmemiş bir davranıştır — sürüm yükseltmelerinde sınanacak** — resmî doküman yalnız "rehberdekiler taranmaz" der, izin istisnasından söz etmez; kod Android 11–16 arası değişmemiş (Android 10'da filtre hiç yok). Faz 6'da her hedef sürüm için regresyon testi zorunlu. İzin manifest'ten düşerse hata sessizdir; `scripts/check_permissions.sh` bunu build'de kırar.
- **Varsayılan telefon uygulaması (`ROLE_DIALER`) olunmayacak** — rehberdeki çağrıları görmenin diğer yolu buydu; tam ekran çağrı arayüzü (cevapla/reddet/tuş takımı/bekletme), Samsung'un arama özelliklerinin kaybı ve kalıcı telefon-katmanı bakım yükü demekti. `READ_CONTACTS` aynı sonucu tek izinle veriyor.
- **`NotificationListenerService` ve `AccessibilityService` yolları reddedildi** — ilki rehberdeki aramada ham numara yerine kişi arama URI'si veriyor ve OEM'e göre değişiyor; ikincisi Play'in erişilebilirlik politikasınca yasak. İkisi de Play'in "kısıtlı veriyi dolaylı yoldan türetme" yasağına yaklaşıyor.
- **Kilit ekranında kart, tam ekran niyetli bildirim + `showWhenLocked` Activity ile gösterilir** — `TYPE_APPLICATION_OVERLAY` penceresi keyguard'ın ALTINDA kalır ve hiçbir pencere bayrağı bunu değiştirmez (`FLAG_SHOW_WHEN_LOCKED` API 27'de kaldırıldı, zaten yalnız Activity pencerelerinde çalışıyordu). Samsung'da doğrulandı: kilitliyken kart görünmüyordu.
- **Ekran kilitliyse tam ekran Activity, kilitsizse overlay** — kilitsizken Activity açmak bayinin o an yaptığı işi bölerdi; kilitliyken overlay hiç görünmüyor. İki yol da aynı `CallerCard` görünümünü kullanır.
- **Arka plandan Activity başlatmanın tek meşru yolu tam ekran niyettir** — Android 10+ arka plan Activity kısıtı `CallScreeningService`'i muaf tutmaz; sistemin gönderdiği `PendingIntent` belgelenmiş muafiyettir.
- **`USE_FULL_SCREEN_INTENT` izni Play riskidir — Faz 6'da "çekirdek işlev" beyanı yapılacak** — Android 14+ bu izni yalnız arama/alarm uygulamalarına otomatik verir ve Play, uymayanlarınkini geri alır. Yan yüklemede sorun çıkmıyor, mağazada çıkabilir. İzin yoksa uygulama ölmez: kilit ekranında bildirime düşer, kurulum sihirbazı kullanıcıdan izni ister.
- **`Measurement.shown` kilitliyken yalnız `fullscreen` yolunu gösterim sayar** — kilitli ekranda overlay çiziliyor, `onDraw` tetikleniyor ve ölçüm "başarılı" kaydediliyordu; metrik kendi başarısızlığını başarı olarak raporluyordu. Sahadan gelen "kart çıkmıyor" bildirimi olmasa fark edilmezdi.
- **GO için en az 5 çağrı ekran kilitliyken sınanmalı** — sahada telefon çoğu zaman cepte ve kilitli; kilitsiz ölçüm ürünün asıl kullanım anını hiç test etmiyor.
- **Kilit ekranında Samsung ve Xiaomi ayrışıyor; iki yol BİRDEN denenir** — Samsung kilitliyken çağrıyı bildirimle gösterir (keyguard örtülmez → tam ekran Activity görünür); MIUI tam ekran çağrı ekranı açar ve Activity'mizin üstüne biner. MIUI çağrı ekranı keyguard'ı örttüğü anda SAW overlay çağrı ekranının üstüne çıkabilir — MIUI'nin "Kilit ekranında göster" izni (`MIUIOP 10020`) tam bunu açar. Kilitli yolda: tam ekran niyet (ölçümü yazar) + sessiz overlay (ölçüm yazmaz, yoksa tek çağrı iki kayıt üretir).
- **Tam ekran niyet GECİKTİRİLEMEZ** — sistem Activity'yi yalnız ekran kapalı/kilitliyken doğrudan açar; 600 ms gecikme denendi, çağrı ekranı ekranı yaktığı için niyet pencereyi kaçırıp sıradan bildirime düştü (Xiaomi'de ölçüldü). Kart hemen açılır, üste çıkma işi sonradan yapılır.
- **Task'lar arası z-order savaşına girilmez** — `REORDER_TO_FRONT` kendi task'ımızda "zaten üstte" dedi ama MIUI InCall task'ının altında kaldık; tekrarlı öne alma çağrı ekranıyla titreşim savaşı demektir. Tek deneme kalır, gerisi overlay+bildirime emanettir.
- **Kilitli ekranda taşıyıcı bildirim silinmez ve `VISIBILITY_PUBLIC` + BigText taşır** — kart çağrı ekranının altında kalırsa müşteri/borç/notu gösteren tek yer o bildirimdir; kartla aynı içeriği taşır.
- **Giden aramalarda da kart gösterilir; go/no-go YALNIZ gelen aramalarla hesaplanır** — bayi müşteriyi geri aradığında da borcu görmek ister; `onScreenCall` giden çağrıları da veriyor (`READ_CONTACTS` sayesinde rehberdekiler dahil). Ölçüm kaydına `dir` alanı eklendi, giden aramalar 20'lik sayımı şişirmez.
- **MIUI'de tam ekran niyet izninin ÖN KOŞULU var: "arka planda açılır pencere"** — MIUI "Tam ekran bildirimleri" anahtarını, kendi "arka planda yeni pencere açma" izni verilmeden açtırmıyor; kurulum sihirbazı Xiaomi'de bu sırayla yönlendirmeli. `OemBatteryGuide` artık MIUI'nin "Diğer izinler" ekranına gider.
- **MIUI kilit ekranında zil sırasında kart gösterilmeye ÇALIŞILMAZ; kart yanıt ve kapanış anlarında yeniden gösterilir** — rakip analizi bunu kesinleştirdi: Play'deki Halı Takip (tüm izinlere ve eski READ_PHONE_STATE yaklaşımına rağmen) bile zil sırasında MIUI çağrı ekranının altında kalıyor; deseni "yanıtta ve kapanışta yeniden tetikle". Bayi siparişi konuşma sırasında alır — kartın asıl lazım olduğu an yanıt anıdır. Zil sırasında bilgiyi zengin bildirim taşır.
- **Yanıt/kapanış tespiti `AudioManager.mode` ile — READ_PHONE_STATE'siz** — mode okumak izin gerektirmez (RINGTONE→çalıyor, IN_CALL→açıldı, NORMAL→bitti); kırmızı çizgi #6 korunur. Süreç konuşma ortasında ölürse izleyici de ölür — en iyi çaba; kart görünürken süreç görünür öncelikte olduğundan risk düşük.
- **Kart dokunulmadan kapanmaz; 120 sn yalnız emniyet süresi** — saha geri bildirimi: 12 sn'lik otomatik kapanma, adres konuşma sırasında lazımken kartı erken kaçırıyordu. Cevapsız çağrıda da kart yeniden gösterilir — bayi kimi kaçırdığını görmeli.
- **Test cihazında rakip arayan-tanıma uygulaması varken alınan sonuçlar geçersizdir** — Xiaomi'deki ilk kilit ekranı denemeleri, aynı anda kendi çağrı ekranını açan ikinci bir uygulamayla (Halı Takip) kirlenmişti; kurulum sihirbazına "benzer uygulama tespiti ve uyarısı" Faz 2'de eklenecek.
- **MIUI izinleri adb/appops ile VERİLEMEZ — kaynak MIUI'nin kendi izin veritabanıdır** — `appops set 10020/10021 allow` yazıldı ve appops "allow" gösterdi, ama MIUI ayar ekranı kapalı gösterip uygulamayı kendi veritabanından denetlemeye devam etti; kart bu yüzden çıkmadı. "Kilit ekranında görüntüle" ve "Arka planda çalışırken yeni pencereler açın" yalnız kullanıcı eliyle, MIUI ayar ekranından açılabilir. Kurulum sihirbazının bu ekranı açıp adım adım tarif etmesi zorunlu; otomatikleştirilemez.
- **Overlay ile yeniden gösterim, keyguard arkasında bekleyen kart Activity'sini kapatır** — kapatmayınca kilit açıldığında üst üste iki kart çıkıyordu (sahada görüldü).
- **Kilitli ekranda keyguard'ı yalnız EN ÜSTTEKİ task örtebilir (AOSP `KeyguardController.mTopOccludesActivity`, tek kazanan)** — alttaki showWhenLocked Activity'ler görünmez; kazanmanın tek yolu çağrı ekranından SONRA en öne geçmek. Kilitli yeniden gösterim bu yüzden overlay değil, Activity yeniden başlatmadır. Overlay kilitli/örtülü keyguard üstünde hiçbir mekanizmayla çizilemez (AOSP + MIUI doğrulandı); MIUI'nin "Kilit ekranında görüntüle" izni Activity'leri yönetir, overlay'leri değil.

## Sürüm yönetimi

- **PR akışı: "PR aç" de, gerisi Claude'da** — gh CLI kuruldu (her iki geliştirici de kurmalı: `winget install GitHub.cli` + `gh auth login`). main'e geçiş istendiğinde Claude dev'deki commit aralığından başlık+tam açıklama yazarak PR'ı açar; merge kararı ve düğmesi insanda. GitHub çok commit'li PR'da açıklamayı otomatik doldurmaz; elle açılan PR'lar için .github/pull_request_template.md iskelet sunar.

- **Stop hook komutu cmd sarmalayicidan bash formuna cevrildi; vardiya senkron kontrolu SessionStart hook'u olarak eklendi** — cmd/IF EXIST tirnak katmanlari hook'u sessizce isleymez kiliyordu (elle test edilerek bulundu); oturum basinda fetch + temiz agacta otomatik ff-pull, gerideyse acik uyari. Kabuk artigi sifir baytlik dosyalar artik kapida filtrelenir.

## Faz 1 — uygulama (coder, 2026-07-11)

- **İki DB rolü: migration `sipario_owner` (imaj superuser), runtime+test `sipario_app` (NOSUPERUSER/NOBYPASSRLS)** — Postgres'te tablo sahibi ve superuser RLS'i atlar; izolasyonu gerçekten kanıtlamak için app/test bağlantısı sahibi-olmayan rol OLMALI. Her tabloda ek `FORCE ROW LEVEL SECURITY` — owner ile yanlışlıkla bağlanılsa da izolasyon çökmesin (kuşak+askı).
- **UUIDv7 trait'i `HasUuids` (architect'in adlandırdığı `HasVersion7Uuids` Laravel 13'te YOK)** — `HasUuids` bu sürümde zaten `Str::uuid7()` üretiyor ve id boş değilse istemcininkini koruyor (offline-first gereği); aynı sonuç, mevcut trait.
- **RLS bağlama noktası middleware (`ResolveTenantContext`), DB connection event DEĞİL** — tenant token satırından çözülüyor ve isteğin transaction ömrünü kontrol etmemiz gerekiyor; istek tek transaction'a sarılır, `set_config('app.tenant_id', ?, true)` yazılır, commit'te otomatik sıfırlanır (kalıcı bağlantıda sızıntı yok).
- **`ResolveTenantContext` middleware önceliği auth:sanctum'dan ÖNCE zorlandı (`prependToPriorityList`)** — Laravel'in öncelik listesi `Authenticate`'i öne alıyordu; tenant bağlamı kurulmadan kullanıcı RLS altında yüklenemeyip 401 dönüyordu (yerel uçtan uca testte yakalandı).
- **Login lookup `SECURITY DEFINER` fonksiyon + sahibi `sipario_auth` (BYPASSRLS); ayrıca `GRANT SELECT ON users,tenants TO sipario_auth`** — tenant bilinmeden email ile kullanıcı bulmanın tek meşru yolu; BYPASSRLS RLS'i atlar ama tablo yetkisi ayrıdır, grant olmadan "permission denied" (yerel testte yakalandı). Nötr 401 ile email enumeration engellenir.
- **`personal_access_tokens`: `uuidMorphs('tokenable')` + `tenant_id` kolonu** — User kimliği UUID olduğundan Sanctum'un varsayılan bigint `morphs`'u token üretiminde patlıyordu (yerel testte yakalandı); `tenant_id` token satırında tutulur ki middleware kullanıcıyı yüklemeden tenant'ı çözebilsin (bu tablo RLS'e tabi değil).
- **Rol modeli: tek `role` sütunu + string PHP enum (`UserRole`), ayrı tablo/paket yok** — yetki `role` middleware ile; `TenantStatus` enum'u login'de trial/active kapısını tutar (diğerleri nötr 403).
- **Email GLOBAL tekil (tenant başına değil)** — login yalnız email+parola alır (mobilde tenant kodu yok), lookup deterministik tek satır dönsün; RLS zaten cross-tenant görünürlüğü engeller.
- **Yönetim paneli salt-okunur DB rolü (`sipario_panel`) Faz 5'e ertelendi** — Faz 1'de yalnız kolon/yapı hazır; rol ve grant'leri para/panel fazında kurulur.
- **Testler ayrı `sipario_test` DB'sinde, gerçek Postgres'e koşar (RLS SQLite'ta yok); phpunit.xml DB_USERNAME=sipario_app** — migration `--database=pgsql_owner` ile, HTTP istekleri app rolüyle. RefreshDatabase yerine owner ile migrate:fresh + TRUNCATE deseni (SET LOCAL doğal sıfırlansın, prod davranışı taklit edilsin).
- **Kök `.gitignore`'daki `.env.*` deseni `.env.example`'ı da yutuyordu; `!**/.env.example` negasyonu eklendi** — Laravel konvansiyonu `.env.example`'ın commit'lenmesini gerektirir (sır içermez, şablondur).
- **Yerel Postgres 16 imajı ICU `tr-TR` collation ile (`--icu-locale=tr-TR`), libc tr_TR.UTF-8 üretilmeden** — Türkçe sıralama/case; docker init betikleri (`10-roles.sh`, `20-test-db.sh`) rolleri ve test DB'sini yalnız ilk initdb'de kurar, CI'da aynı SQL elle koşulur.
- **Docker Postgres host portu 55432 (5432 değil)** — geliştirici makinelerinde Laragon'un yerli PostgreSQL'i 5432'yi tutuyor; standart portta uygulama sessizce yanlış sunucuya bağlanıyordu (sahada yakalandı), standart-dışı port bu çakışma sınıfını bütün makinelerde kökten kapatır. Konteyner içi port 5432 kalır; CI service container'ı etkilenmez.
- **Yan dal/worktree açılmaz; iş doğrudan dev'de yapılır, main'e yalnız dev→main PR ile gidilir (kullanıcı kararı, 2026-07-11)** — Faz 1 izole worktree+ara dalda yürüdü ve dosyalar yerelde "kayboldu" (kafa karışıklığı); akış tek hat: yerel çalışma = dev, dev→main PR, merge kararı insanda. `.claude/settings.json`'a `worktree.bgIsolation=none` eklendi ki arka plan oturumları da doğrudan dev'de çalışabilsin.

## Faz 1 — güvenlik denetimi (2026-07-13)

- **Login + korumalı API hız sınırı (`throttle`), limitler `AppServiceProvider`'da** — F1: zamanlama yan-kanalı kapalıydı ama deneme SAYISI sınırsızdı (kaba kuvvet/credential-stuffing). Login: aynı e-posta+IP'ye 5/dk + tek IP'den 20/dk (yayılı numaralandırma); korumalı grup: kullanıcı/IP başına 60/dk (çalınan token istismarı + DoS). Aşımda 429.
- **429 (throttle) yanıtı `server_time` taşımaz — bilinçli kapsam sınırı** — throttle exception olarak render edilir, `AppendServerTime`'ın post-işlemesini atlar (auth 401 exception'ları da öyle); `server_time` yalnız denetleyiciden dönen normal JsonResponse'larda garanti. İstemci offset'i başarılı yanıtlardan gelir, 429'da gerekmez. Genişletmek Faz 2+ işi.
- **Güvenlik başlıkları middleware'i (`SecurityHeaders`) tüm api yanıtlarında** — F3: `X-Content-Type-Options=nosniff`, `X-Frame-Options=DENY`, `Referrer-Policy=no-referrer`, `X-Permitted-Cross-Domain-Policies=none`. HSTS burada DEĞİL — TLS ters vekilde sonlanır, HSTS orada verilir (yanlış http ortamda istemci kilitlenmesin).
- **`config/cors.php` yayımlandı: yüzey `api/*`, origin env-driven, credentials kapalı** — F4: Laravel varsayılanı joker `*`; mobil bearer CORS uygulamaz ama Faz 5 tarayıcı paneli için joker risk. İzinli origin'ler `CORS_ALLOWED_ORIGINS` env'inden (tanımsızsa boş → hiçbir tarayıcı origin'i, mobil etkilenmez); bearer token çerez istemediği için `supports_credentials=false`.
- **Sanctum `token_prefix` varsayılanı `sipario_`** — F2: sızan token'ları depo/GitHub secret-scanning yakalayabilsin. Token doğrulaması öneki yok sayar, üretimde henüz token yok (geriye dönük risk sıfır). Token süresizliği (`expiration=null`) offline-first gereği bilinçli KORUNDU — saha cihazı sunucuya günlerce ulaşamadan tam çalışmalı; kilit `valid_until` ile (Faz 5), token süresiyle değil.
- **larastan/phpstan seviye 6 kuruldu (`phpstan.neon`), kalite kapısındaki "atlanan statik analiz" boşluğu kapandı (F6)** — 4 gerçek tip bulgusu KÖK NEDENDEN düzeltildi (baskılama yok): modele `casts()`-türevli `@property` blokları (larastan enum/Carbon tiplerini kolon şemasından çıkaramıyordu), enum erişimi `$x->value` (savunmacı `instanceof BackedEnum` ölü daldı), `CreateTenant`'ta nullable `trial_ends_at` için `?->`.
- **Doğrulama: pint + phpstan(sıfır hata, seviye 6) + phpunit 37/37(105 assert) + composer audit(CVE yok) yeşil** — 3 yeni güvenlik testi (`SecurityHardeningTest`: 429 rate-limit, güvenlik başlıkları, izinsiz origin CORS reddi) eklendi; mevcut 34 izolasyon/auth testi bozulmadı.

## Faz 2 — mimari (2026-07-13)

- **İstemci sunucuya ASLA doğrudan REST CRUD yapmaz; tek yazma yüzeyi `POST /sync/push`, tek okuma yüzeyi `GET /sync/pull`** — yazma yolu outbox üzerinden (DECISIONS "Senkron"); "müşteri/sipariş CRUD" istemcide yereldir (Drift) ve outbox olayı üretir, sunucu yalnız push/pull görür.
- **Delta pull kaynağı merkezî append-only `sync_changes` günlüğü (tenant başına monoton `seq`), canlı tablolarda per-row seq YOK** — tek sıralı akış paging/cursor'ı önemsizleştirir, silme bir tombstone satırdır, para tabloları transport günlüğünden mantıken ayrık kalır.
- **Tenant başına `seq`, push transaction'ında `tenant_sync_state` satırı `SELECT ... FOR UPDATE` ile tahsis edilir** — satır kilidi commit'e kadar tutulduğundan seq atama sırası = commit sırası; CDC "sıra boşluğu / kayıp güncelleme" sınıfı kökten kapanır (korku #2).
- **Idempotency `processed_events(tenant_id, client_event_id)` UNIQUE ile; tekrar gönderim duplicate olarak AYNI sonucu döner** — "gönderdim mi acaba" durumu yok (DECISIONS "Senkron"); ağ zaman aşımı sonrası retry çift-uygulama yapmaz.
- **İlk kurulum snapshot'ı canlı tablolardan REPEATABLE READ transaction'da okunur, cursor = o an görülen `last_seq`; sonraki pull'lar `sync_changes WHERE seq > cursor`** — snapshot temel çizgiyi kurar, delta üstüne biner; snapshot sırasındaki yazımlar seq>cursor ile bir sonraki delta'da gelir (kayıp yok).
- **Varlık alanları LWW: her satırda `updated_occurred_at` + `updated_device_id`; gelen olay ancak `occurred_at` daha yeniyse (eşitlikte `device_id` büyükse) uygulanır, değilse ack'lenip yok sayılır** — DECISIONS "son yazan kazanır + device_id eşitlik kırıcı"nın sunucu tarafı; reddedilen olay da ack alır ki istemci retry'ı durdursun.
- **`order_events` Faz 2'de KULLANILIR (sipariş baştan olay-kaynaklı, `orders.status/total_kurus` önbellek); `ledger_entries` şeması kurulur ama YAZIMI Faz 3'te** — team-lead kararı "outbox baştan doğru olsun"; sipariş durumu olaylardan türer, defter iş akışı sonraki faz.
- **Tüm yeni tablolar Faz 1 desenini birebir izler: `tenant_id` + ENABLE/FORCE RLS + `NULLIF(current_setting('app.tenant_id',true),'')::uuid` politikası, ana tabloda `unique(tenant_id,id)`, çocukta `(tenant_id,parent_id)` bileşik FK** — izolasyon join'siz ve veritabanı seviyesinde; cross-tenant referans imkânsız.
- **Push/pull uçları cross-tenant test matrisine eklenir (RouteCoverageGuard aksi halde build'i kırar); silme fiziksel değil tombstone (`deleted_at` + `sync_change op=delete`)** — kırmızı çizgi #1 "sürekli kanıtla"; veri silinmez (kırmızı çizgi #2/#5), tombstone senkronla yayılır.
- **Drift `sipario.db` dosya adını, `customers`/`customer_phones` tablo adlarını, `customers.balance_kurus` ve `phone_last10` indeksini Faz 0 sözleşmesi olarak KORUR; native salt-okunur okur** — arayan tanımanın 1 sn bütçesi bu indekse ve önbelleğe bağlı; Drift journal modu native salt-okunur açıcıyla uyumlu doğrulanmalı (WAL riski açık).

## Faz 2 — uygulama (coder, 2026-07-13)

- **Push'ta her olay ayrı savepoint'te (`DB::transaction` iç içe) uygulanır; istemci-kaynaklı hata (InvalidArgument veya SQLSTATE 22P02/23502/23503/23505/23514) o olayı `rejected` yapar, parti bozulmaz** — Postgres'te hatalı statement transaction'ı zehirler; savepoint tek olayı geri alıp partiyi kurtarır. Referanslar (customer_id vb.) yazımdan ÖNCE RLS-kapsamlı SELECT ile doğrulanır ki FK ihlali hiç oluşmasın (zehirlenme önlenir).
- **`ChangeApplier` (domain mutasyonu + LWW/append) ile `SyncService` (seq/idempotency/pull) ayrı sınıflar** — 500 satır sınırı + tek sorumluluk; ChangeApplier seq bilmez, SyncService domain bilmez.
- **`balance_kurus` istemciden YAZILAMAZ; ledger olayında sunucu `SUM(amount_kurus)`'u defterden yeniden kurar** — DECISIONS "önbellek bozulursa defterden kurulur"; istemci upsert payload'ından balance düşürülür.
- **Her çocuk tabloda composite `(tenant_id,parent_id)` FK'ye EK olarak doğrudan `tenant_id→tenants` cascade FK** — nullable parent'lı `orders`/`ledger_entries` (müşterisiz sipariş/kayıt) tenant silinince composite FK MATCH SIMPLE ile atlanıp yetim kalırdı; doğrudan FK cascade'i garanti eder.
- **`tenant_sync_state` satırı `Provisioning`'de kurulur; push ayrıca `ON CONFLICT DO NOTHING` ile self-heal yapar** — factory ile açılan tenant'lar (testler) satırı almaz, self-heal onları da kapsar (ve yolu test eder).
- **İstemci Drift TEK KİRACIDIR: tablolar sunucu aynası MİNUS `tenant_id`** — cihazda tek bayi oturur; izolasyon sunucuda RLS, istemcide oturum. Faz 0 `sipario.db` + `customers`/`customer_phones`/`phone_last10` sözleşmesi korunur, `address` kolonu `customer_addresses`'e normalize edildi (native adres gerekiyorsa ayrı sorgu — 1 sn hot-path'te değil).
- **Drift `schemaVersion=2`: v1→v2 ADDİTİF migration (architect kabul kriteri) — `customers`/`customer_phones` DROP EDİLMEZ, yalnız `updated_occurred_at`/`updated_device_id`/`deleted_at` ALTER ADD COLUMN + yeni tablolar CREATE** — native sözleşme (tablo/kolon adları, `phone_last10` indeksi, `balance_kurus`) ve mevcut veri korunur; Faz 0'ın `customers.address` kolonu orphan/nullable kalır (adres artık `customer_addresses`'e yazılır). NOT NULL `updated_occurred_at` mevcut satırlara `1970` varsayılanıyla eklenir → sunucu güncellemesi LWW'de kazanır. `PRAGMA journal_mode=TRUNCATE` (WAL değil) native salt-okunur açıcı için (gerçek cihazda doğrulanacak — kabul kriteri).
- **Drift codegen (Dart 3.10) friction ÇÖZÜLDÜ: `sqlite3>=3.3` ve `objective_c` native build-hook'ları `dart run build_runner`ın AOT derlemesini kırıyor** — `path_provider` kaldırıldı (DB yolu için `sqflite getDatabasesPath` yeterli, objective_c gitti); üretilmiş `app_database.g.dart` COMMIT'lenir; yeniden üretim gerekirse pubspec'teki kapalı `sqlite3 <3.3` override'ı geçici açılır (yönerge pubspec'te). Runtime/`flutter test` sqlite3 3.4 ister (drift 2.34 API'si) — override kapalı normaldir.
- **`order_events` id'sini SUNUCU üretir, istemci `client_event_id` ile dedup eder; `ledger_entries` id'sini istemci üretir, id ile dedup** — append tablolarında "yoksa ekle"; istemci kendi lokal olayını sunucudan geri gelince ikizlemez.
- **İstemci çakışma: pull bir varlık değişikliği getirdiğinde o varlık için daha yeni `pending` outbox düzenlemesi varsa YEREL korunur** — gönderilmemiş yerel düzenleme sunucuda kazanacağından üzerine yazılmaz; append tabloları bu kuraldan muaf.
- **larastan/phpstan bu checkout'ta vendor'da YOKTU, `composer install` ile kuruldu (lock'ta vardı); kalite kapısı seviye 6'da 0 hata** — Faz 1 F6 kararı gereği statik analiz koşulmalı.
- **Cross-tenant referans doğrulaması TÜM yabancı id'lerde simetrik: `order_lines.product_id` ve `ledger_entries.related_order_id` de yazımdan önce RLS-kapsamlı `exists()` ile doğrulanır (tester bulgusu)** — customer_id doğrulanıyordu ama bu ikisi doğrulanmadan yazılıyordu; veri henüz sızmıyordu ama Faz 3 raporları bu id'leri join'lerse gerçek sızıntı olurdu. Başka bayinin ürün/siparişine referans artık InvalidArgument + savepoint ile reddedilir (kırmızı çizgi #1).
- **Append-only defter/olay değişmezliği VERİTABANI SEVİYESİNDE zorlanır: `sipario_app`'ten `ledger_entries`, `order_events`, `sync_changes`, `processed_events` üzerinde UPDATE/DELETE REVOKE edilir (migration 000211, reviewer bulgusu)** — kırmızı çizgi #2 "silinmez/ezilmez" koda değil DB iznine bağlanır (FORCE RLS felsefesiyle simetrik savunma-derinliği); bir kod hatası bile geçmişi ezemez. Uygulama bu tablolara yalnız INSERT eder; `sipario_owner` (superuser) revoke'tan muaf (bakım açık). `tenant_sync_state` DAHİL DEĞİL (seq push'ta UPDATE edilir). `AppendOnlyLedgerTest` app rolüyle UPDATE/DELETE denemesini 42501 ile kanıtlar.
- **`ChangeApplier` 500 satır sınırını aştığı için üçe bölündü (reviewer): `ChangeApplier` (dispatch + basit varlık LWW + defter), `OrderChangeApplier` (sipariş olay mantığı), `SyncPayload` (ortak `change()`/`req()` saf yardımcıları)** — davranış aynı, 66/66 test yeşil kaldı.
- **Claude Code hook komutları BASH biçiminde yazılır (`f="$CLAUDE_PROJECT_DIR/..."; if [ -f "$f" ]; then node "$f" <komut>; fi`), ASLA `cmd /c` ile değil** — hook'lar bu makinede Git Bash üzerinden çalışıyor; MSYS yol dönüşümü `/c` argümanını `C:/`'ye çevirip etkileşimli cmd açıyor, hook sessizce hiç çalışmıyor (belirti: hook çıktısında "Microsoft Windows [Version..." banner'ı + ham JSON). Ayrıca hook `timeout` alanı SANİYE cinsindendir, milisaniye değil.
