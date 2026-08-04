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
            $tenantId = $bearer !== null
                ? PersonalAccessToken::findToken($bearer)?->tenant_id
                : null;

            /*
             * WEB OTURUMU DÜŞÜŞÜ (bayinin hesap paneli). Mobil istemci kimliğini bearer token ile
             * taşır; tarayıcıdaki patron ise oturum çerezi ile. `users` tablosunda RLS FORCE açık
             * olduğu için `auth:web` kullanıcıyı yüklemeye çalıştığında app.tenant_id kurulmamışsa
             * SIFIR SATIR görür — istek sessizce "misafir" sayılır ve giriş yapmış bayi hesap
             * sayfasına hiç giremez. Yani bu satır olmadan `auth:web` bu mimaride ÇALIŞAMAZ.
             *
             * Değer güvenilirdir: oturuma yalnız parola doğrulandıktan SONRA yazılır (Site\Login,
             * Site\Register) ve oturum sunucu tarafında imzalıdır — istemci kendi tenant'ını
             * seçemez. Token yolu her zaman önceliklidir; ikisi birden varsa token kazanır.
             */
            if ($tenantId === null && $request->hasSession()) {
                $oturumdaki = $request->session()->get('subscription_tenant_id');
                $tenantId = is_string($oturumdaki) && $oturumdaki !== '' ? $oturumdaki : null;
            }

            if ($tenantId !== null) {
                // set_config parametre alır (SET LOCAL bind kabul etmez) → enjeksiyon güvenli,
                // üçüncü arg true = LOCAL (transaction ömrü).
                DB::statement(
                    "SELECT set_config('app.tenant_id', ?, true)",
                    [$tenantId]
                );
            }

            // Kimlik yoksa app.tenant_id set edilmez → RLS sıfır satır → auth 401/misafir.
            return $next($request);
        });
    }
}
