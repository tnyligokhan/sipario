<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Her JSON API yanıtına sunucu saatini (ISO8601 UTC) ekler.
 * DECISIONS: sunucu her yanıtta kendi saatini döner; istemci offset tutar (esnafın telefon
 * saati yanlış olabilir, occurred_at düzeltilmiş saatle yazılır).
 * Yanıt JSON değilse (dosya, redirect vb.) dokunulmaz.
 */
class AppendServerTime
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        if ($response instanceof JsonResponse) {
            $data = $response->getData(true);

            if (is_array($data) && ! array_key_exists('server_time', $data)) {
                $data['server_time'] = now()->utc()->toIso8601String();
                $response->setData($data);
            }
        }

        return $response;
    }
}
