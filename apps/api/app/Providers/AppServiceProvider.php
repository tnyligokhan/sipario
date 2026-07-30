<?php

namespace App\Providers;

use App\Payment\IyzicoPaymentGateway;
use App\Payment\PaymentGateway;
use App\Support\Geocoding\Geocoder;
use App\Support\Geocoding\GoogleGeocoder;
use App\Support\Geocoding\KademeliGeocoder;
use App\Support\Geocoding\NullGeocoder;
use App\Support\Geocoding\YandexGeocoder;
use App\Support\Konum\KonumDeposu;
use App\Support\Konum\VeritabaniKonumDeposu;
use App\Support\Route\GoogleRoutesMotoru;
use App\Support\Route\RotaMotoru;
use App\Support\Route\YakinKomsuMotoru;
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

        // Oto sıralama motoru SOYUT: Google Routes (gerçek yol ağı, paralı) ya da kuş uçuşu
        // yakın komşu (bedava, saf). Sürücü env'den seçilir; anahtar yoksa yakın komşuya düşer.
        $this->app->singleton(RotaMotoru::class, fn () => $this->rotaMotoruKur());

        // Canlı konum deposu SOYUT: bugün tek satırlık bir Postgres tablosu, ama veri uçucu ve
        // yüksek yazma hızlı — yarın Redis'e taşınırsa değişen tek satır burasıdır, controller
        // ve istemci sözleşmesi aynı kalır. Singleton DEĞİL (durumsuz, isteğe özgü bir bağlam
        // taşımaz; konteyner her çözümde yenisini kursa da maliyeti yok).
        $this->app->bind(KonumDeposu::class, VeritabaniKonumDeposu::class);
    }

    /**
     * Yapılandırılmış rota motorunu kurar. Anahtarı olmayan ya da tanınmayan sürücü YAKIN
     * KOMŞUYA düşer — Null'a değil: sıralama hiçbir koşulda kullanılamaz hâle gelmemeli.
     * Yanlış bir env satırı en fazla "sıra biraz daha kaba" demektir, özellik kapanmaz.
     */
    private function rotaMotoruKur(): RotaMotoru
    {
        $yakinKomsu = new YakinKomsuMotoru;

        if ((string) config('rota.surucu', RotaMotoru::YAKIN_KOMSU) !== RotaMotoru::GOOGLE) {
            return $yakinKomsu;
        }

        $google = new GoogleRoutesMotoru(
            apiKey: (string) config('rota.google.api_key', ''),
            baseUrl: (string) config('rota.google.base_url', ''),
            timeout: max(1, (int) config('rota.timeout', 8)),
        );

        return $google->hazirMi() ? $google : $yakinKomsu;
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
            // Kademeli: önce Google; Yandex yalnız Google kapıyı bulamayınca ve günlük tavana
            // kadar. Sonuçlar birleştirilmez, seçim kullanıcıda. (`coklu` eski addır — birkaç
            // saat yaşadı; alias bırakıldı ki eski bir .env sürücüyü sessizce null'a düşürmesin.)
            'kademeli', 'coklu' => new KademeliGeocoder(
                google: $google(),
                yandex: $yandex(),
                yandexGunlukTavan: (int) config('geocoding.yandex.daily_limit', 900),
            ),
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

        // Oto sıralama: geocode gibi PARAYLA ölçülür (Google Routes). Kontör toplam hakkı sınırlar
        // ama EŞZAMANLILIĞI sınırlamaz — ön bakış kilitsiz olduğu için yarışan istekler tek
        // kontöre karşılık birden çok ücretli çağrı yakabilirdi. Dakikalık kiracı sınırı bu
        // yarışın maliyet tavanıdır; meşru kullanım (kurye sıralamayı arka arkaya iki kez basar)
        // rahatça sığar.
        RateLimiter::for('rota', function (Request $request) {
            $kimlik = (string) ($request->user()?->tenant_id ?: $request->ip());

            return [Limit::perMinute(5)->by('rota:dk:'.$kimlik)];
        });

        // Coğrafi kodlama: parayla ölçülen diğer uç nokta. Sınır KİRACI başınadır (kullanıcı başına
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

        // Konum kalp atışı: parayla ölçülmez ama SÜREKLİdir — uygulama açık olduğu sürece
        // düzenli çağrılır. Genel `throttle:api` (60/dk) burada fazla cömert: bozuk bir istemci
        // döngüsü o payı tek başına yer ve aynı kullanıcının gerçek isteklerini (senkron, rota)
        // 429'a düşürürdü. Sınır KULLANICI başınadır, kiracı başına DEĞİL: beş cihazlı bir bayide
        // kiracı sınırı olsaydı beş kuryeden biri hakkı tüketip diğer dördünü haritadan silerdi.
        RateLimiter::for('konum', fn (Request $request) => Limit::perMinute(
            max(1, (int) config('konum.kalp_atisi_limit', 6))
        )->by('konum:'.($request->user()?->id ?: $request->ip())));
    }
}
