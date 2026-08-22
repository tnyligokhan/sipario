<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Application Name
    |--------------------------------------------------------------------------
    |
    | This value is the name of your application, which will be used when the
    | framework needs to place the application's name in a notification or
    | other UI elements where an application name needs to be displayed.
    |
    */

    'name' => env('APP_NAME', 'Laravel'),

    /*
    |--------------------------------------------------------------------------
    | API Sürümü — SemVer (kural: CLAUDE.md → "Sürümleme")
    |--------------------------------------------------------------------------
    |
    | SUNUCU SÖZLEŞMESİNİN sürümü. Mobil uygulamanın sürümünden BAĞIMSIZDIR
    | (`apps/mobile/pubspec.yaml`) ve ona eşitlenmez — ikisini aynı numaraya
    | bağlamak, ikisinden birinin numarasını anlamsız kılar.
    |
    | KODDA sabittir, `env()` ile DEĞİL: sürüm çalışan koda aittir, ortama değil.
    | Ortamdan okunsaydı canlı ile test farklı sürüm bildirebilir ve numara
    | "hangi kod koşuyor" sorusunu cevaplamaz hâle gelirdi.
    |
    | ARTIRMA (bu projede sürüm = istemci-sunucu sözleşmesi, kod büyüklüğü değil):
    |   MAJOR → eski istemci ÇALIŞAMAZ (alan kaldırıldı/anlamı değişti/zorunlu
    |           alan eklendi). Telefonlar offline-first çalışıp günlerce eski
    |           sürümde kalabildiği için bu bir OLAYDIR; eski istemcinin ne
    |           yapacağı önceden yazılı olarak kararlaştırılır.
    |   MINOR → geriye dönük uyumlu yeni alan/uç nokta.
    |   PATCH → sözleşmeyi değiştirmeyen düzeltme.
    |
    | 1.0.0 başlangıcı bilinçli: bu sözleşme 2026-08-07'den beri ÜRETİMDE ve
    | gerçek bayilere hizmet veriyor. Mobil tarafın 0.x'te olması mağaza
    | çıkışına bağlı ayrı bir eşiktir, API'yi ilgilendirmez.
    |
    | 1.1.0 (2026-08-10): her JSON yanıta `api_version` alanı + kimliksiz
    | `GET /v1/version` uç noktası. İkisi de EKLEME — eski istemci her ikisini
    | de görmezden gelir, yani MINOR. Artış deploy'a ERTELENMEDİ, bilinçli:
    | sürüm çalışan koda aittir (env'e değil), o yüzden alanı ekleyen commit
    | ile numarayı artıran commit AYNI olmak zorundadır. Ayrı bırakılsaydı
    | "1.0.0" iki farklı sözleşmeyi anlatırdı ve numaranın tek işi olan
    | "hangi kod koşuyor" sorusunu cevaplayamazdı.
    |
    | 1.4.0 (2026-08-13): `cash_handover` yükünde OPSİYONEL `reverses_handover_id`
    | (ara tahsilat iptali — ters satır, silme yok). Saf EKLEME: alanı hiç
    | göndermeyen eski istemci aynen çalışır, pull'da bilmediği anahtarı yok
    | sayar. Zorunlu alan eklenmedi, hiçbir alanın anlamı değişmedi → MINOR.
    | Mobil sürümüyle EŞİTLENMEZ: iki hat bağımsızdır (CLAUDE.md "Sürümleme").
    |
    | 1.7.0 (2026-08-14): PUSH BİLDİRİMİ. Sunucu, uygulanan senkron olaylarından
    | üçünde (sipariş kuryeye atandı · teslim edildi · kasa devredildi) ilgili
    | cihazlara FCM üzerinden VERİ dürtüsü gönderir. Sözleşme açısından saf
    | EKLEME ve bu yüzden MINOR: hiçbir uç nokta, alan ya da anlam değişmedi;
    | `POST /devices` zaten var olan `push_token` alanını artık gerçekten
    | kullanıyor. Push'u tanımayan eski istemci hiçbir şey kaybetmez — dürtü
    | yalnız bir HIZLANDIRICIDIR, veri mevcut senkronla akmaya devam eder.
    |
    | DAVRANIŞ DÜZELTMESİ (aynı sürümde): `POST /devices` ve giriş yolundaki
    | cihaz bloğu, `push_token` GÖNDERİLMEDİĞİNDE artık alana `null` YAZMIYOR.
    | Eskisi "verilmedi"yi "boşalt" sayıyordu; FCM jetonu girişten sonra
    | asenkron geldiği için bu, her açılışta jetonu silerdi.
    |
    */

    /*
    | 1.8.0 (2026-08-14): İKİ YENİ PUSH OLAYI — `siparis_iptal` (sipariş iptal
    | edildi ya da kuryeden geri alındı → o ana kadar ATANMIŞ kuryeye) ve
    | `yeni_cihaz` (hesap yeni bir telefonda açıldı → yöneticilere). Saf EKLEME,
    | yani MINOR: uç nokta, alan ya da anlam değişmedi; olayları tanımayan eski
    | istemci dürtüyü yok sayar ve veri mevcut senkronla akmaya devam eder.
    */

    /*
    | 1.11.0 (2026-08-18): KAPANIŞI GERİ ALMA + YÖNETİCİ ONAYI. İki ekleme:
    |
    | (1) `day_closings.reverses_closing_id` — kapatılmış bir gün/kurye hesabı
    | artık geri alınabiliyor. Kayıt SİLİNMEZ: geri alma, tabloya yazılan TERS
    | BİR SATIRdır (`cash_handovers.reverses_handover_id` deseninin aynısı) ve
    | orijinal kapanış kanıt olarak yerinde kalır.
    |
    | (2) `POST /auth/parola-dogrula` — oturumdaki kullanıcının parolasını
    | doğrular ("bu ekrana dokunan gerçekten sen misin?"). Kullanıcı adı
    | GÖVDEDEN ALINMAZ; doğrulanan her zaman token'ın sahibidir.
    |
    | MINOR: uç nokta eklendi, alan eklendi, hiçbir mevcut anlam değişmedi.
    |
    | ⚠️ ESKİ İSTEMCİ İÇİN BİLİNÇLİ BEDEL: 0.28.0 ve öncesi bir telefon, geri
    | alma satırını "ikinci bir kapanış" olarak indirir ve o günü hâlâ KAPALI
    | görür — yani yeni yeteneği kullanamaz. Yanlış PARA göstermez (arşiv
    | satırları olduğu gibi durur). Alternatif (yeni bir entity_type) olayın
    | eski istemcide tamamen KAYBOLMASI demekti; görünür ama etkisiz olmak,
    | hiç olmamaktan iyidir.
    |
    | 1.10.0 (2026-08-17): LWW SANİYE-ALTI AYRIMI. Çakışma çözümü ("son yazan
    | kazanır") aynı saniyeye düşen iki yazımı ayıramıyor, karar `device_id`
    | karşılaştırmasına iniyordu — yani kazanan daha YENİ olan değil, kimliği
    | BÜYÜK olandı ve çevrimdışı bir cihazın eski yazımı yeniyi ezebiliyordu.
    |
    | İKİ KIRPICI VARDI, ikisi de kapatıldı: (1) karar veren 19 kolon
    | `timestamptz(0)` idi → `timestamptz(6)`; (2) Eloquent'in damga biçimi
    | `Y-m-d H:i:s` (mikrosaniyesiz) olduğu için model, gelen `.900000`ı
    | KAYDEDERKEN kendisi kırpıyordu → `MikrosaniyeliDamga` trait'i (14 model).
    | Yalnız birincisi düzeltilseydi hiçbir şey değişmezdi.
    |
    | MINOR ve ESKİ İSTEMCİ KIRILMAZ: uygulama damgayı en başından mikrosaniyeli
    | GÖNDERİYORDU; değişen tek şey sunucunun artık o hassasiyeti KAYBETMEMESİ.
    | Uç nokta, alan ve anlam aynı; yalnız var olan bir alanın değer aralığı
    | genişledi. Değer DEĞİŞMEDİĞİ için `sync_changes`e delta da düşmez.
    |
    | 1.9.0 (2026-08-15): GÜNLÜK YEDEK BİLDİRİMİ. `backup` sidecar'ının ürettiği
    | dosyalar bugüne kadar yalnız kendi volume'ünde duruyordu ve hiçbir yerden
    | görünmüyordu; artık `app`/`scheduler` onları SALT-OKUNUR görüyor, panelde
    | superadmin'e açık bir indirme route'u (`panel.yedek.indir`) ve her sabah
    | 08:00'de bağlantıyı postalayan bir zamanlanmış görev var.
    |
    | MINOR ve MOBİLE TAMAMEN NÖTR: hiçbir API uç noktası, alanı ya da anlamı
    | değişmedi — eklenen yüzey panel (web) tarafındadır. Sürümün artmasının
    | sebebi sunucu davranışının GENİŞLEMESİdir; telefonlar bu sürümü hiç fark
    | etmeden çalışmaya devam eder.
    |
    | 1.12.0 (2026-08-19): SİTE METİNLERİ, HUKUK PAKETİ, ÖLÇÜM VE SEO.
    |
    | Üç iş kolu birden web yüzeyinde bitti:
    |  · Hukuk metinleri BAŞTAN YAZILDI ve 5'ten 10 belgeye çıktı (kullanım
    |    koşulları, gizlilik politikası, açık rıza, veri işleyen eki, KVKK
    |    başvuru formu eklendi). `subscription.legal_docs` haritası büyüdü,
    |    `subscription.legal` sürümleri 2026-07-15'ten 2026-08-19'a çekildi ve
    |    yeni bir `terms_version` hattı açıldı.
    |  · Google Analytics 4 + Consent Mode v2 eklendi; çerez rıza bandı ve
    |    `config/analitik.php` yeni. Site CSP'si ölçüm kaynaklarına açıldı,
    |    `Referrer-Policy` yüzeye göre ayrıştı.
    |  · `sitemap.xml`, `llms.txt`, genişletilmiş `robots.txt`, OG/Twitter meta
    |    ve JSON-LD yapısal verisi eklendi.
    |
    | NEDEN MINOR VE NEDEN MOBİL ETKİLENMEZ: hiçbir API uç noktası, alanı ya da
    | anlamı değişmedi — değişen her şey tarayıcı yüzeyindedir. Telefonlar bu
    | sürümü fark etmeden çalışmaya devam eder.
    |
    | ⚠️ TEK GERÇEK SÖZLEŞME DEĞİŞİKLİĞİ, KABUL SÜRÜMLERİNİN İLERLEMESİDİR:
    | `subscription_payments.consent_version` artık "…:2026-08-19" yazacak.
    | Eski kayıtlar 2026-07-15 ile duruyor ve DURMALIDIR — o bayiler o günkü
    | metni kabul etti. Sürümleri geriye dönük eşitlemek, kabul kaydını bir
    | delil olmaktan çıkarırdı.
    |
    | 1.13.0 (2026-08-20): TESLİMİ KİM YAPTI + TEZGÂH HESABI.
    |
    | İki iş kolu, ikisi de GERİYE DÖNÜK UYUMLU:
    |  · `orders.delivered_by_user_id` eklendi (migration 004016). `delivered`
    |    order olayının payload'ı artık OPSİYONEL bir `delivered_by_user_id`
    |    taşıyabiliyor; sunucu onu `assigned_user_id` ile AYNI desende doğrular
    |    (RLS-kapsamlı `User::exists`) ve önbelleği en son olaydan türetir.
    |    Anahtarı GÖNDERMEYEN eski istemciler aynen çalışır — alan null kalır ve
    |    okuma katmanı atamaya düşer.
    |  · Bayi kendi web panelinden TEZGÂH hesabı açabiliyor
    |    (`Provisioning::createStaff`). Kota artık patron dışındaki her aktif
    |    hesabı sayar: tezgâh bedava kalsaydı "3 kurye hesabı" sözü karşılıksız
    |    kalırdı — tezgâh da atama hedefi olabiliyor, yani teslimat yapabiliyor.
    |
    | NEDEN MINOR: yeni alan OPSİYONELDİR ve hiçbir mevcut alanın anlamı
    | değişmedi. Sahadaki eski telefon yeni sunucuyla çalışmaya devam eder;
    | tek farkı, yaptığı teslimatın "kim yaptı" bilgisini taşımamasıdır.
    |
    | ⚠️ SESSİZ DAVRANIŞ DEĞİŞİKLİĞİ (kayda geçsin): `KuryeKotasi` sayımı
    | genişledi. Üretimde `operator` rollü hesap AÇAN bir yol yoktu (ölçüldü),
    | yani bugün kimsenin kotası daralmıyor; ama kural bundan sonra geçerlidir.
    |
    | 1.14.0 (2026-08-22): TEK HESAP = TEK CİHAZ.
    |
    | Bir kullanıcı yeni bir telefonda giriş yaptığında o hesabın DİĞER bütün
    | token'ları düşürülür; eski telefon bir sonraki isteğinde 401 alır ve
    | gövdede `code: "oturum_baska_cihazda"` görür. Düşen token'ın cihazındaki
    | push jetonu da boşaltılır — oturumu kapanan telefon o bayinin
    | bildirimlerini almaya devam edemez.
    |
    | KAPSAM KULLANICIDIR, BAYİ DEĞİL: patronun girişi kuryenin telefonunu
    | düşürmez (ayrı hesaplar). Aynı hesabı iki telefonda paylaşan bir bayi
    | bundan sonra sırayla birbirini düşürür — istenen davranış budur.
    |
    | NEDEN MINOR VE NEDEN MAJOR DEĞİL: hiçbir uç nokta, alan ya da anlam
    | kaldırılmadı; `code` alanı EKLEMEDİR. Eski istemci (sürüm < 0.42) yeni
    | sunucuyla çalışmaya devam eder — düşürüldüğünde giriş ekranına
    | kendiliğinden dönmez, senkron bandında "Oturum doğrulanmadı" yazar ve
    | kullanıcı elle çıkış yapıp girer. Yani davranış eksik, kırık değil.
    |
    | 1.15.0 (2026-08-22): KURYE MÜŞTERİ GÖRÜNÜRLÜĞÜ YETKİSİ.
    |
    | `courier_can_see_all_customers` eklendi (migration 004018) ve mevcut üç
    | durumlu modele girdi: `tenant_settings` üzerinde NOT NULL DEFAULT false
    | (bayi varsayılanı), `users` üzerinde NULLABLE (null = devral). Yeni yetki
    | `TenantSetting::KURYE_IZINLERI`'nden türeyen HER yerde kendiliğinden akar:
    | profil uygulayıcısı, `team` bloğu, panel formu.
    |
    | SUNUCU HİÇBİR ŞEYİ SÜZMEZ ve bu bilinçli: uygulama offline-first çalışır,
    | senkron snapshot'ı bayinin bütün müşterilerini telefona indirmeye devam
    | eder. Kısıtlama EKRANDA uygulanır (`courier_can_see_all_orders` deseninin
    | aynısı). Sunucuda süzmek, kuryeye ATANDIĞI anda müşterisi henüz inmemiş
    | bir sipariş göstermek olurdu — kapıda adressiz teslim, kırmızı çizgi #3.
    |
    | NEDEN MINOR: alan EKLEMEDİR; hiçbir uç nokta, alan ya da anlam kalkmadı.
    | Eski istemci bilmediği anahtarı yok sayar ve bugünkü gibi çalışır.
    |
    | 1.16.0 (2026-08-22): İPTAL ONAY AKIŞI.
    |
    | İki yeni sipariş olayı: `cancel_requested` (kurye iptal İSTER) ve
    | `cancel_rejected` (yönetici reddeder). İkisi de `EventValidator::OPS`
    | sözlüğüne girdi ve `orderStatusEvent` dalından uygulanıyor.
    |
    | ⚠️ İKİSİ DE SİPARİŞİN DURUMUNU DEĞİŞTİRMEZ. `recomputeOrder` status'ü hâlâ
    | yalnız `cancelled`/`delivered`tan türetir; talep açıkken sipariş `open`
    | kalır ve teslim edilebilir. Bu, özelliğin tamamıdır: talep siparişi
    | kapatsaydı "Reddet" düğmesi geri alınamaz bir işi düzeltmeye çalışırdı.
    |
    | ONAYIN AYRI BİR OLAYI YOKTUR: onaylanan talep siparişi gerçekten iptal
    | eder, yani `cancelled` doğar. İkinci bir "approved" olayı, durumu türeten
    | iki ayrı kural demekti.
    |
    | PUSH: `PushOlayi::SiparisIptalTalebi` (alıcı: yöneticiler) ve
    | `SiparisIptalReddedildi` (alıcı: talebi AÇAN kurye, olay geçmişinden
    | türetilir). İKİSİ DE `siparis_iptal_onayi` kategorisini taşır — bayi için
    | tek bir anahtar; metni ayıran şey yükteki `olay` alanıdır.
    |
    | NEDEN MINOR: yeni op'lar EKLEMEDİR. Eski istemci onları hiç göndermez ve
    | `order_events` içinde tanımadığı bir satır görürse yok sayar (durum
    | türetmesi yalnız bildiği olaylara bakar).
    */

    'version' => '1.16.0',

    /*
    |--------------------------------------------------------------------------
    | Application Environment
    |--------------------------------------------------------------------------
    |
    | This value determines the "environment" your application is currently
    | running in. This may determine how you prefer to configure various
    | services the application utilizes. Set this in your ".env" file.
    |
    */

    'env' => env('APP_ENV', 'production'),

    /*
    |--------------------------------------------------------------------------
    | Application Debug Mode
    |--------------------------------------------------------------------------
    |
    | When your application is in debug mode, detailed error messages with
    | stack traces will be shown on every error that occurs within your
    | application. If disabled, a simple generic error page is shown.
    |
    */

    'debug' => (bool) env('APP_DEBUG', false),

    /*
    |--------------------------------------------------------------------------
    | Application URL
    |--------------------------------------------------------------------------
    |
    | This URL is used by the console to properly generate URLs when using
    | the Artisan command line tool. You should set this to the root of
    | the application so that it's available within Artisan commands.
    |
    */

    'url' => env('APP_URL', 'http://localhost'),

    /*
    |--------------------------------------------------------------------------
    | Application Timezone
    |--------------------------------------------------------------------------
    |
    | Here you may specify the default timezone for your application, which
    | will be used by the PHP date and date-time functions. The timezone
    | is set to "UTC" by default as it is suitable for most use cases.
    |
    */

    'timezone' => 'UTC',

    /*
    |--------------------------------------------------------------------------
    | Application Locale Configuration
    |--------------------------------------------------------------------------
    |
    | The application locale determines the default locale that will be used
    | by Laravel's translation / localization methods. This option can be
    | set to any locale for which you plan to have translation strings.
    |
    */

    'locale' => env('APP_LOCALE', 'en'),

    'fallback_locale' => env('APP_FALLBACK_LOCALE', 'en'),

    'faker_locale' => env('APP_FAKER_LOCALE', 'en_US'),

    /*
    |--------------------------------------------------------------------------
    | Encryption Key
    |--------------------------------------------------------------------------
    |
    | This key is utilized by Laravel's encryption services and should be set
    | to a random, 32 character string to ensure that all encrypted values
    | are secure. You should do this prior to deploying the application.
    |
    */

    'cipher' => 'AES-256-CBC',

    'key' => env('APP_KEY'),

    'previous_keys' => [
        ...array_filter(
            explode(',', (string) env('APP_PREVIOUS_KEYS', ''))
        ),
    ],

    /*
    |--------------------------------------------------------------------------
    | Maintenance Mode Driver
    |--------------------------------------------------------------------------
    |
    | These configuration options determine the driver used to determine and
    | manage Laravel's "maintenance mode" status. The "cache" driver will
    | allow maintenance mode to be controlled across multiple machines.
    |
    | Supported drivers: "file", "cache"
    |
    */

    'maintenance' => [
        'driver' => env('APP_MAINTENANCE_DRIVER', 'file'),
        'store' => env('APP_MAINTENANCE_STORE', 'database'),
    ],

];
