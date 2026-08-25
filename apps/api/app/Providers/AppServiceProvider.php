<?php

namespace App\Providers;

use App\Http\Middleware\ResolveTenantContext;
use App\Mail\ParolaSifirlama;
use App\Models\User;
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
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Contracts\Auth\CanResetPassword;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;
use Livewire\Livewire;

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
        $this->parolaSifirlamaPostasiniKur();

        /*
         * LIVEWIRE'IN ALPINE PAKETİNİ CSP-GÜVENLİ SÜRÜME AL (2026-08-04, `csp_safe` sıkılaştırması).
         *
         * `config('livewire.csp_safe')` yayın (publish) edilmiş bir dosya değil — vendor'ın kendi
         * varsayılanı `false`. Burada, tam paket config'i (`config/livewire.php`, ~400 satır)
         * kopyalamak yerine TEK anahtarı ezmek tercih edildi: gelecekteki bir Livewire sürümü
         * varsayılan dosyayı değiştirirse, yayınlanmış bir kopya o değişikliği SESSİZCE görmezden
         * gelirdi; bu satır her zaman en güncel paket config'inin ÜSTÜNE biner.
         *
         * `boot()` İÇİNDE olması ZORUNLU: Laravel tüm sağlayıcıların `register()`ını bitirdikten
         * SONRA `boot()`lara geçer, ve Livewire'ın kendi `register()`ı `mergeConfigFrom()` ile
         * varsayılan değeri BURADAN önce yazar — `register()`da yazsaydım hangi sağlayıcının önce
         * çalıştığına bağlı bir yarış olurdu.
         *
         * `@livewireScripts` artık `livewire.csp.js`i basar: bu paket `new Function`/`eval`
         * içermez (ölçüldü — normal `livewire.js`de bir tane var, CSP sürümünde sıfır) ve
         * `SecurityHeaders::script-src`ten `'unsafe-eval'` bu yüzden kaldırılabildi. Bedeli: Alpine'ın
         * kendi sandbox'lı öznitelik değerlendiricisi HTML içindeki ifadelerde globallere
         * (`window`, `navigator`, `setTimeout`, ...) ve obje-içi kısaltılmış metot/getter tanımına
         * izin vermez — bu depodaki her ihlal `public/js/alpine.js`teki gerçek `Alpine.data()`
         * bileşenlerine taşındı (bkz. o dosyanın belge başlığı: hangi ekranın hangi mantığı taşıdığı
         * tek tek yazılı, Alpine'ın gerçek CSP değerlendiricisi Node'da izole çalıştırılıp hem eski
         * ifadelerin kırıldığı hem yenilerinin çalıştığı ölçüldü).
         */
        config(['livewire.csp_safe' => true]);

        /*
         * KİRACI BAĞLAMI LIVEWIRE'IN İKİNCİ İSTEĞİNDE DE KURULMALI.
         *
         * Livewire ilk GET'ten sonra `/livewire/update`e gider ve orada route'un middleware'ini
         * yeniden çalıştırmaz — yalnız KENDİ kalıcı listesini uygular. O listede
         * `Illuminate\Auth\Middleware\Authenticate` VAR ama kiracı bağlamını kuran middleware YOK.
         * İkisi ayrışınca `auth:web` kullanıcıyı `users` üzerinden yüklemeye çalışır, RLS FORCE
         * yüzünden sıfır satır görür ve hesap panelindeki HER eylem AuthenticationException ile
         * düşer — sayfa açılır, hiçbir düğme çalışmaz.
         *
         * Bu, 5c-3'te panelde öğrenilen dersin ("route middleware'i Livewire'ı korumaz") ters
         * yönüdür: burada route middleware'i Livewire'a ULAŞMIYOR.
         *
         * Panel (`auth:admin`) etkilenmez — `admin_users` ayrı bir provider'dır ve RLS'e tabi
         * değildir; bu satır yalnız bayinin hesap panelini ayakta tutar.
         */
        Livewire::addPersistentMiddleware(ResolveTenantContext::class);
    }

    /**
     * PAROLA SIFIRLAMA POSTASI — Laravel'in varsayılanını Sipario şablonuyla değiştirir.
     *
     * DÜZELTTİĞİ ARIZA ÖLÇÜLDÜ: `.env`de `APP_LOCALE=tr` yazıyor ama depoda `lang/tr` dizini
     * YOK. Laravel'in `ResetPassword` bildirimi metnini `__('Reset Password')` gibi anahtarlarla
     * kurar; çeviri bulunamayınca anahtarın KENDİSİ basılır. Sonuç: Türkçe bir üründe, hesabına
     * giremeyen esnafa İngilizce bir posta gidiyordu. Bu iki satır o yolu kapatır ve çeviri
     * dosyası bağımlılığını tümden kaldırır.
     *
     * NEDEN BURADA, `Livewire\Site\Parola` İÇİNDE DEĞİL: ikisi de UYGULAMA GENELİ ayardır,
     * isteğe özgü değil. `createUrlUsing` daha önce `Parola::baglantiGonder()` içinde her çağrıda
     * yeniden kuruluyordu; o yerleşim sessiz bir tuzak taşıyordu — parola sıfırlamayı BAŞKA bir
     * yol tetiklerse (panelden destek talebi, konsol komutu, ileride eklenecek bir uç nokta)
     * `createUrlUsing` hiç çalışmaz ve Laravel varsayılan `password.reset` adını arar; o ad bu
     * depoda YOKTUR (bizimki `site.parola.yenile`), yani posta ya patlar ya yanlış adrese
     * götürür. Boot'ta bir kez kurmak bu yolların hepsini birden doğru yapar.
     */
    private function parolaSifirlamaPostasiniKur(): void
    {
        // Bağlantı adresi: bizde route adı `site.parola.yenile` (/parola/yenile/{token}).
        // E-posta parametresi ŞART — token tek başına hangi hesaba ait olduğunu söylemez,
        // `ParolaYenile` kullanıcıyı adresten bulur.
        ResetPassword::createUrlUsing(fn (CanResetPassword $kullanici, string $token): string => route(
            'site.parola.yenile',
            ['token' => $token, 'email' => $kullanici->getEmailForPasswordReset()],
        ));

        ResetPassword::toMailUsing(function (CanResetPassword $kullanici, string $token): ParolaSifirlama {
            $ad = $kullanici instanceof User && trim($kullanici->name) !== ''
                ? $kullanici->name
                : 'değerli bayimiz';

            return (new ParolaSifirlama(
                yetkili: $ad,
                url: route('site.parola.yenile', [
                    'token' => $token,
                    'email' => $kullanici->getEmailForPasswordReset(),
                ]),
                // Süreyi UYDURMUYORUZ: broker'ın gerçek ömrü config'dedir ve orayı değiştiren
                // biri postadaki cümleyi güncellemeyi unutursa yalan söylemiş oluruz.
                gecerlilikDakika: (int) config('auth.passwords.users.expire', 60),
            ))
                /*
                 * ⚠️ `->to(...)` ZORUNLUDUR VE UNUTULDUĞUNDA ARIZA TAMAMEN SESSİZDİR.
                 * (2026-08-12'de canlıda yaşandı, kök neden burasıydı.)
                 *
                 * `Notification::toMail()` bir `MailMessage` döndürdüğünde alıcıyı `MailChannel`
                 * KENDİSİ ekler (`$notifiable`ın adresinden). Ama bir `Mailable` döndürdüğünde
                 * kanal onu olduğu gibi `$mailable->send($mailer)` ile gönderir ve alıcı ekleme
                 * adımını ATLAR — sorumluluk tümüyle buraya geçer. Alıcısız ileti Symfony'de
                 * `LogicException: An email must have a "To", "Cc", or "Bcc" header.` ile düşer.
                 *
                 * Ve o istisna KULLANICIYA GÖRÜNMEZ: `Livewire\Site\Parola::baglantiGonder()`
                 * gönderim hatalarını numaralandırmayı önlemek için bilerek yutup `report()`
                 * eder (DECISIONS 2026-08-09). Yani ekran "bağlantı gönderildi" der, posta hiç
                 * çıkmaz, hiçbir yerde kırmızı yanmaz. Bu satır o sessizliğin tek koruyucusudur;
                 * regresyon testi `ParolaSifirlamaPostasiTest` ile kilitli.
                 */
                ->to($kullanici->getEmailForPasswordReset());
        });
    }

    /**
     * Hız sınırları (güvenlik denetimi bulgusu F1 — kaba kuvvet / kimlik bilgisi doldurma).
     *
     * Zamanlama yan-kanalı zaten kapalı (AuthController), ama sınırsız deneme sözlük saldırısına
     * kapı açar. İki katmanlı sınır: (1) hedefli — aynı firma kodu+kullanıcı adı+IP'ye kaba
     * kuvvet, (2) yayılı — tek IP'den birçok hesaba numaralandırma. Aşımda 429 döner
     * (AppendServerMeta yine ekler).
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

        // Parola sıfırlama isteği (mobil): AYRI SINIRLAYICI, `login`in kotasını PAYLAŞMAZ.
        //
        // Paylaşsaydı iki yönlü zarar verirdi: (a) parolasını unutan kullanıcı birkaç deneme
        // sonra GİRİŞ yapamaz hâle gelirdi — tam da girmeye çalışırken, (b) sıfırlama isteğiyle
        // giriş denemesi aynı sayaçta olunca saldırgan ucuz sıfırlama istekleriyle meşru
        // kullanıcının giriş hakkını tüketebilirdi.
        //
        // TAVANLAR SİTEDEKİYLE AYNI DÜZENDE (`Livewire\Site\Parola`): kimlik+IP çifti dar,
        // IP geniş. Uç nokta POSTA ÜRETİYOR — burası bir kimlik doğrulama yüzeyi değil, bir
        // posta bombardımanı yüzeyidir ve sınır ona göre kurulur.
        RateLimiter::for('parola-sifirla', function (Request $request) {
            $kimlik = Str::lower((string) $request->input('tenant_code'))
                .'/'.Str::lower((string) $request->input('username'));

            return [
                Limit::perMinute(3)->by('parola:kimlik:'.sha1($kimlik.'|'.$request->ip())),
                Limit::perMinute(15)->by('parola:ip:'.sha1((string) $request->ip())),
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
