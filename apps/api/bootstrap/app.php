<?php

use App\Http\Middleware\AppendServerMeta;
use App\Http\Middleware\BlockApiHostWebRoutes;
use App\Http\Middleware\EnsureRole;
use App\Http\Middleware\RejectRevokedToken;
use App\Http\Middleware\ResolveTenantContext;
use App\Http\Middleware\SecurityHeaders;
use Illuminate\Contracts\Auth\Middleware\AuthenticatesRequests;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        /*
         * X-Forwarded-* BAŞLIKLARINA GÜVEN — ÜRETİMDE ZORUNLU (2026-08-05).
         *
         * ⚠️ BU AYAR TÜNELE AİT DEĞİLDİR, SİLİNMEZ. Aşağıdaki hikâye onu doğuran olaydır ve
         * kayıt olarak duruyor; ama üretim dalı (`production ? '*'`) Coolify/Traefik arkasında
         * koşan HER istek için gereklidir. Tünel 2026-08-16'da kaldırıldı, bu satır kalmalı.
         *
         * DOĞURAN OLAY: saha sunucusu tarayıcıya cloudflared tüneliyle (HTTPS) çıkıyordu;
         * cloudflared yerelde koşar ve 127.0.0.1:8000'e DÜZ HTTP ile bağlanıp gerçek şemayı
         * `X-Forwarded-Proto: https` ile söylerdi. Bu satır olmadan Laravel o başlığı YOK SAYAR
         * ve `asset()`/`route()` her mutlak URL'i `http://` üretir. Sonuç: HTTPS sayfada HTTP
         * stylesheet = AKTİF KARIŞIK İÇERİK — mobil Chrome bunu istisnasız engeller (izin verme
         * seçeneği de yoktur) ve site açan herkese TAMAMEN STİLSİZ görünür. Sahada birebir
         * yaşandı: kullanıcı "büyük sorunlar var" dedi, sayfa çıplak HTML'di; masaüstünde
         * `http://127.0.0.1:8000` ile bakan herkes ise hiçbir şey görmedi (şema uyuşuyor,
         * karışık içerik doğmuyor). Aynı sınıf arıza üretimde de mümkündür — orada proxy
         * Traefik'tir.
         *
         * Üretimde (Coolify/Traefik arkası) proxy Docker iç ağından gelir (172.x.x.x) —
         * loopback DEĞİL. Container doğrudan internete açık olmadığı için '*' güvenlidir.
         *
         * Geliştirme dalı BİLİNÇLİ dar tutuldu (yalnız loopback): '*' güvenmek, LAN'dan
         * doğrudan gelen bir isteğin sahte X-Forwarded-* başlıklarıyla şema/istemci-IP yalanı
         * söyleyebilmesi demektir (hız sınırı anahtarları istemci IP'sinden türetiliyor —
         * bkz. AppServiceProvider::limitler). Yerelde şu an araya giren bir proxy yok, ama
         * kapsamı daraltan bu satırın maliyeti sıfır; genişletmenin maliyeti yukarıdaki yalandır.
         */
        $middleware->trustProxies(
            at: env('APP_ENV') === 'production' ? '*' : ['127.0.0.1', '::1'],
        );

        $middleware->alias([
            'tenant' => ResolveTenantContext::class,
            'role' => EnsureRole::class,
            // Düşürülmüş token'a SEBEBİNİ söyler (tek hesap = tek cihaz). Kapıyı Sanctum tutar;
            // bu yalnız açıklama katmanıdır — gerekçe RejectRevokedToken başlığında.
            'oturum' => RejectRevokedToken::class,
        ]);

        // Kiracı bağlamı, auth:sanctum kullanıcıyı RLS altında yüklemeden ÖNCE kurulmalı.
        // Laravel'in middleware öncelik listesi Authenticate'i normalde öne alır; bu yüzden
        // ResolveTenantContext'i açıkça auth'tan önce önceliklendiriyoruz (yoksa 401 döner).
        $middleware->prependToPriorityList(
            before: AuthenticatesRequests::class,
            prepend: ResolveTenantContext::class,
        );

        // Aynı gerekçe: düşürülmüş token'a sebebini söyleyen katman da auth'tan ÖNCE koşmalı,
        // yoksa Sanctum çıplak 401 ile sırayı ona hiç bırakmaz. Rota grubunda zaten doğru sırada
        // yazılı; buradaki satır önceliklendiricinin onu auth'ın arkasına atmayacağını GARANTİLER.
        $middleware->prependToPriorityList(
            before: AuthenticatesRequests::class,
            prepend: RejectRevokedToken::class,
        );

        // Tüm api yanıtlarına: server_time (DECISIONS: sunucu her yanıtta saatini döner) +
        // api_version (sözleşme sürümü — istemci çarpıklığı görünür olsun) + güvenlik başlıkları (F3).
        $middleware->api(append: [
            AppendServerMeta::class,
            SecurityHeaders::class,
        ]);

        // WEB yüzeyine de güvenlik başlıkları (güvenlik incelemesi 5c-3). F3'te başlıklar yalnız
        // api'ye eklenmişti çünkü o sırada tarayıcı yüzeyi yoktu; 5c ile panel geldi ve panel
        // ÇERÇEVEYE GÖMÜLEBİLİR durumdaydı. `X-Frame-Options: DENY` olmadan, oturumu açık bir
        // admin'e görünmez bir iframe üzerinden bayi kilitletmek/patron şifresi sıfırlatmak
        // (clickjacking) mümkündü — panelin eylemleri tek tıklık Livewire düğmeleridir.
        $middleware->web(append: [
            SecurityHeaders::class,
            BlockApiHostWebRoutes::class,
        ]);

        /*
         * Oturumsuz istekleri DOĞRU giriş ekranına yolla. İki AYRI kimlik dünyası var ve
         * karıştırılmamalı: panel BİZE ait (admin guard), hesap sayfası BAYİYE ait (web guard).
         *
         * `hesap` satırı olmadan oturumu düşen bayi 500 görürdü: null dönünce Laravel `route('login')`
         * adını arar, bu projede öyle bir route YOKTUR ve `RouteNotFoundException` fırlar.
         *
         * API yolları hâlâ null döner → JSON 401 (mobil istemcinin beklediği davranış, değişmedi).
         */
        $middleware->redirectGuestsTo(function (Request $request): ?string {
            if ($request->is('panel*')) {
                return route('panel.login');
            }

            return $request->is('hesap*') ? route('subscription.login') : null;
        });

        // Abonelik callback (Faz 5b) iyzico DIŞ POST'udur → CSRF muaf (imza/idempotensi ile korunur).
        $middleware->validateCsrfTokens(except: ['abonelik/callback']);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );
    })->create();
