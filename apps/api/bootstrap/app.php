<?php

use App\Http\Middleware\AppendServerTime;
use App\Http\Middleware\EnsureRole;
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
        $middleware->alias([
            'tenant' => ResolveTenantContext::class,
            'role' => EnsureRole::class,
        ]);

        // Kiracı bağlamı, auth:sanctum kullanıcıyı RLS altında yüklemeden ÖNCE kurulmalı.
        // Laravel'in middleware öncelik listesi Authenticate'i normalde öne alır; bu yüzden
        // ResolveTenantContext'i açıkça auth'tan önce önceliklendiriyoruz (yoksa 401 döner).
        $middleware->prependToPriorityList(
            before: AuthenticatesRequests::class,
            prepend: ResolveTenantContext::class,
        );

        // Tüm api yanıtlarına: server_time (DECISIONS: sunucu her yanıtta saatini döner) + güvenlik başlıkları (F3).
        $middleware->api(append: [
            AppendServerTime::class,
            SecurityHeaders::class,
        ]);

        // WEB yüzeyine de güvenlik başlıkları (güvenlik incelemesi 5c-3). F3'te başlıklar yalnız
        // api'ye eklenmişti çünkü o sırada tarayıcı yüzeyi yoktu; 5c ile panel geldi ve panel
        // ÇERÇEVEYE GÖMÜLEBİLİR durumdaydı. `X-Frame-Options: DENY` olmadan, oturumu açık bir
        // admin'e görünmez bir iframe üzerinden bayi kilitletmek/patron şifresi sıfırlatmak
        // (clickjacking) mümkündü — panelin eylemleri tek tıklık Livewire düğmeleridir.
        $middleware->web(append: [
            SecurityHeaders::class,
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
