<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Her JSON API yanıtına SUNUCUNUN KENDİSİNE dair iki alan ekler: saat ve sözleşme sürümü.
 *
 * `server_time` (ISO8601 UTC) — DECISIONS: sunucu her yanıtta kendi saatini döner; istemci offset
 * tutar (esnafın telefon saati yanlış olabilir, occurred_at düzeltilmiş saatle yazılır).
 *
 * `api_version` (SemVer, `config/app.php`) — istemci-sunucu SÜRÜM ÇARPIKLIĞINI görünür kılar.
 * 2026-08-09'da sürüm tanımlandı ama HİÇBİR yanıtta okunmuyordu; bu depoda aynı gün üç kez ödenen
 * "tanımlı ama bağlı değil" deseninin dördüncüsü olacaktı. Sürüm bir yanıtta görünmüyorsa, sahadaki
 * telefonun hangi sözleşmeyle konuştuğu ancak sunucuya girip dosyaya bakılarak bilinir — ve
 * uygulama offline-first olduğu için telefonlar günlerce eski sürümde kalabiliyor.
 *
 * NEDEN TEK TEK UÇ NOKTALAR DEĞİL, MIDDLEWARE: sürümü yalnız `sync/pull` yanıtına koymak, bir gün
 * eklenecek yeni uç noktanın onu taşımamasına yol açardı (`server_time` tam olarak bu sebeple
 * burada). Alan, uç noktanın değil TAŞIMANIN özelliğidir.
 *
 * İKİSİ DE ÜZERİNE YAZMAZ (`array_key_exists`): bir uç nokta bu alanları kendi doldurduysa
 * (ör. public `GET /v1/version`) onun değeri kalır — middleware yalnız EKSİĞİ tamamlar.
 *
 * Yanıt JSON değilse (dosya, redirect vb.) dokunulmaz.
 */
class AppendServerMeta
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        if ($response instanceof JsonResponse) {
            $data = $response->getData(true);

            if (is_array($data)) {
                $degisti = false;

                if (! array_key_exists('server_time', $data)) {
                    $data['server_time'] = now()->utc()->toIso8601String();
                    $degisti = true;
                }

                if (! array_key_exists('api_version', $data)) {
                    $data['api_version'] = (string) config('app.version');
                    $degisti = true;
                }

                if ($degisti) {
                    $response->setData($data);
                }
            }
        }

        return $response;
    }
}
