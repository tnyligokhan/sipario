<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

/**
 * Kiracı bağlamını kurar (kırmızı çizgi #1'in runtime yarısı).
 *
 * İki tuzağı birden çözer:
 *  1. auth:sanctum kullanıcıyı yüklerken users RLS'ine takılır (henüz tenant set değil) → 401.
 *     Bu yüzden tenant, kullanıcı YÜKLENMEDEN önce doğrudan token satırından çözülür
 *     (personal_access_tokens RLS'e tabi değildir).
 *  2. set_config(...,true)/SET LOCAL yalnız transaction içinde yaşar. Tüm istek tek transaction'a
 *     sarılır; istek bitince commit ile app.tenant_id otomatik sıfırlanır → kalıcı bağlantıda bile
 *     bir sonraki istek temiz başlar, tenant sızıntısı olmaz (güvenli varsayılan).
 *
 * Bu middleware auth:sanctum'dan ÖNCE çalışmalıdır.
 */
class ResolveTenantContext
{
    public function handle(Request $request, Closure $next): Response
    {
        $bearer = $request->bearerToken();

        return DB::transaction(function () use ($request, $next, $bearer) {
            if ($bearer !== null) {
                $token = PersonalAccessToken::findToken($bearer);

                if ($token !== null && $token->tenant_id !== null) {
                    // set_config parametre alır (SET LOCAL bind kabul etmez) → enjeksiyon güvenli,
                    // üçüncü arg true = LOCAL (transaction ömrü).
                    DB::statement(
                        "SELECT set_config('app.tenant_id', ?, true)",
                        [$token->tenant_id]
                    );
                }
            }

            // Token geçersiz/yoksa app.tenant_id set edilmez → RLS sıfır satır → auth:sanctum 401 döner.
            return $next($request);
        });
    }
}
