# DECISIONS.md — Sipario

Her satır bir karar ve tek cümlelik gerekçesi. Yeni kararlar sona eklenir, eskiler silinmez;
değişen bir karar "~~üstü çizili~~ → yeni karar" biçiminde güncellenir.

## Stack

- **Mobil: Flutter + native Kotlin köprüsü** — ekipte Flutter deneyimi var, tek kod tabanı Android+iOS; arayan tanıma zaten native yazılacağı için Flutter engel değil.
- **API: Laravel 12 / PHP 8.3** — ekipte Laravel deneyimi var ve bakım bizde kalacak; stack seçimini domine eden maliyet kalemi bu.
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
