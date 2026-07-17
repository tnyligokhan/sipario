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

        // Panel (Faz 5c) oturumsuz istekleri panel login'e yönlendir; API yolları JSON 401 döner (değişmez).
        $middleware->redirectGuestsTo(
            fn (Request $request) => $request->is('panel*') ? route('panel.login') : null,
        );

        // Abonelik callback (Faz 5b) iyzico DIŞ POST'udur → CSRF muaf (imza/idempotensi ile korunur).
        $middleware->validateCsrfTokens(except: ['abonelik/callback']);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );
    })->create();
