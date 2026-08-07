<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * api. hostname'inden gelen web isteklerini engeller.
 *
 * Mobil trafiğin geldiği kapıdan (api.sipario.com.tr) yönetim paneline ve pazarlama
 * sitesine erişilmemesi gerekir. API rotaları ayrı middleware grubuyla çalışır ve
 * bu middleware'den ETKİLENMEZ.
 *
 * Yalnız host adı 'api.' ile başlayan isteklerde devreye girer; yerel geliştirmede
 * (localhost, 127.0.0.1) hiçbir etkisi yoktur.
 */
class BlockApiHostWebRoutes
{
    public function handle(Request $request, Closure $next): Response
    {
        $host = $request->getHost();

        if (str_starts_with($host, 'api.')) {
            abort(404);
        }

        return $next($request);
    }
}
