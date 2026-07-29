<?php

namespace App\Providers;

use App\Payment\IyzicoPaymentGateway;
use App\Payment\PaymentGateway;
use App\Support\Geocoding\CokluGeocoder;
use App\Support\Geocoding\GeoAday;
use App\Support\Geocoding\Geocoder;
use App\Support\Geocoding\GoogleGeocoder;
use App\Support\Geocoding\NullGeocoder;
use App\Support\Geocoding\YandexGeocoder;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Ödeme sağlayıcısı SOYUT (FAZ 5b): üretimde iyzico (sandbox/prod anahtarları config'den);
        // testler FakePaymentGateway ile swap eder. Abonelik durumu tek doğru kaynak SUNUCU.
        $this->app->bind(PaymentGateway::class, function () {
            /** @var array{api_key: string, secret_key: string, base_url: string} $cfg */
            $cfg = config('subscription.iyzico');

            return new IyzicoPaymentGateway($cfg['api_key'], $cfg['secret_key'], $cfg['base_url']);
        });

        // Coğrafi kodlama SOYUT (adres → koordinat): bugün Yandex, anahtar gelince Google.
        // Sürücü env'den seçilir; anahtar yoksa NullGeocoder bağlanır ve HİÇ dış çağrı yapılmaz
        // (CI ve yerel geliştirme gerçek servise çıkmaz). Testler bu bağı fake ile swap eder.
        $this->app->singleton(Geocoder::class, fn () => $this->geocoderKur());
    }

    /**
     * Yapılandırılmış sürücüyü kurar. Anahtarı olmayan sürücü Null'a DÜŞER — yanlış
     * yapılandırma sessiz bir 500 değil, kullanıcıya dürüst bir "bu kurulumda tanımlı değil"
     * mesajı üretir.
     */
    private function geocoderKur(): Geocoder
    {
        $timeout = max(1, (int) config('geocoding.timeout', 8));
        $ulke = (string) config('geocoding.bias.country', 'tr');
        $bbox = (string) config('geocoding.bias.bbox', '');

        $yandex = fn () => new YandexGeocoder(
            apiKey: (string) config('geocoding.yandex.api_key', ''),
            baseUrl: (string) config('geocoding.yandex.base_url', ''),
            timeout: $timeout,
            lang: (string) config('geocoding.bias.lang', 'tr_TR'),
            bbox: $bbox,
        );

        $google = fn () => new GoogleGeocoder(
            apiKey: (string) config('geocoding.google.api_key', ''),
            baseUrl: (string) config('geocoding.google.base_url', ''),
            timeout: $timeout,
            ulke: $ulke,
            bbox: $bbox,
        );

        $surucu = match ((string) config('geocoding.driver', 'null')) {
            'yandex' => $yandex(),
            'google' => $google(),
            // İkisini birden sor, adayları birleştir, seçimi kullanıcıya bırak. Anahtarı olmayan
            // sağlayıcıyı CokluGeocoder kendi eler; biri düşerse diğeri özelliği ayakta tutar.
            'coklu' => new CokluGeocoder([
                ['ad' => GeoAday::KAYNAK_YANDEX, 'geocoder' => $yandex()],
                ['ad' => GeoAday::KAYNAK_GOOGLE, 'geocoder' => $google()],
            ]),
            default => new NullGeocoder,
        };

        return $surucu->hazirMi() ? $surucu : new NullGeocoder;
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiters();
    }

    /**
     * Hız sınırları (güvenlik denetimi bulgusu F1 — kaba kuvvet / kimlik bilgisi doldurma).
     *
     * Zamanlama yan-kanalı zaten kapalı (AuthController), ama sınırsız deneme sözlük saldırısına
     * kapı açar. İki katmanlı sınır: (1) hedefli — aynı firma kodu+kullanıcı adı+IP'ye kaba
     * kuvvet, (2) yayılı — tek IP'den birçok hesaba numaralandırma. Aşımda 429 döner
     * (AppendServerTime yine ekler).
     */
    private function configureRateLimiters(): void
    {
        RateLimiter::for('login', function (Request $request) {
            // Kimlik artık firma kodu + kullanıcı adı ÇİFTİdir (tasarım `s-giris.jsx`); hedefli
            // sınır bu çiftin üzerinden kurulur. Tek başına kullanıcı adıyla anahtarlamak
            // yanlış olurdu: "patron" her bayide vardır, bir bayiye kaba kuvvet uygulayan
            // saldırgan bütün bayilerin girişini kilitlerdi.
            // Büyük/küçük harf normalize (login lookup lower() ile eşleşir).
            $kimlik = Str::lower((string) $request->input('tenant_code'))
                .'/'.Str::lower((string) $request->input('username'));

            return [
                Limit::perMinute(5)->by('login:cred:'.$kimlik.'|'.$request->ip()),
                Limit::perMinute(20)->by('login:ip:'.$request->ip()),
            ];
        });

        // Korumalı API: kimlik doğrulanmışsa kullanıcı başına, değilse IP başına dakikada 60.
        // Çalınan bir token'ın istismar hızını ve genel DoS yüzeyini sınırlar.
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(60)
            ->by($request->user()?->id ?: $request->ip()));

        // Coğrafi kodlama: PARAYLA ölçülen tek uç nokta. Sınır KİRACI başınadır (kullanıcı başına
        // değil) — bir bayinin beş cihazı aynı kotayı paylaşır; aksi halde cihaz ekleyerek kota
        // çoğaltılırdı. Günlük tavan, bozuk bir istemci döngüsünün bütün bayilerin özelliğini
        // kapatmasını engeller: zarar isteği yapan bayide kalır.
        RateLimiter::for('geocode', function (Request $request) {
            $kimlik = (string) ($request->user()?->tenant_id ?: $request->ip());

            return [
                Limit::perMinute(20)->by('geo:dk:'.$kimlik),
                Limit::perDay(max(1, (int) config('geocoding.daily_limit', 300)))->by('geo:gun:'.$kimlik),
            ];
        });
    }
}
