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

    'version' => '1.8.0',

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
