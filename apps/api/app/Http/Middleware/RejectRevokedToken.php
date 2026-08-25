<?php

namespace App\Http\Middleware;

use App\Enums\TokenDusmeSebebi;
use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

/**
 * Düşürülmüş token'a NEDEN düşürüldüğünü söyler (2026-08-22 — tek hesap, tek cihaz).
 *
 * ══ NE İŞE YARAR ════════════════════════════════════════════════════════════════════════════
 * Kullanıcı yeni bir telefonda giriş yapınca eski telefonun token'ı düşürülür
 * (`AuthController::digerCihazlariDusur`). Bu middleware olmasaydı eski telefon yalnız çıplak
 * bir 401 görürdü ve kullanıcıya "sebepsiz çıkış yaptım" dedirtirdi. Buradaki tek katkı
 * SEBEBİ TAŞIMAKTIR: yanıt gövdesindeki `code`, mobil istemcinin giriş ekranına yazacağı
 * cümleyi seçer.
 *
 * ══ KAPIYI BU TUTMUYOR ══════════════════════════════════════════════════════════════════════
 * ⚠️ Güvenlik burada DEĞİL. Düşürülen token'ın `expires_at`i de geçmişe çekilir, yani Sanctum
 * (`Guard::isValidAccessToken`) onu zaten reddeder. Bu middleware unutulsa ya da yeni bir rota
 * grubunda takılmasa bile düşürülmüş token İŞE YARAMAZ — yalnız kullanıcı sebebini öğrenemez.
 * Bu sıralama bilinçlidir: açıklama katmanının kaybolması bir güvenlik açığı doğurmamalı.
 *
 * ══ NEDEN `tenant`TAN SONRA, `auth:sanctum`TAN ÖNCE ═════════════════════════════════════════
 * `auth:sanctum`tan sonra koşsaydı hiç sıra gelmezdi: Sanctum düşmüş token'ı zaten reddeder ve
 * çıplak 401 döner. `personal_access_tokens` RLS'e tabi olmadığı için kiracı bağlamı gerekmez;
 * yine de `tenant`ın açtığı transaction'ın içinde koşması sorun değildir (tek okuma).
 */
class RejectRevokedToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $bearer = $request->bearerToken();

        if ($bearer !== null) {
            $token = PersonalAccessToken::findToken($bearer);

            // `findToken` süreye BAKMAZ (hash eşleşmesiyle satırı bulur) — düşürülmüş token
            // burada hâlâ görünür, kapatılan yalnız Sanctum'un kabulüdür.
            if ($token !== null && $token->revoked_at !== null) {
                $sebep = TokenDusmeSebebi::tryFrom((string) $token->revoked_reason);

                return response()->json([
                    'message' => $sebep?->mesaj() ?? 'Oturumunuz kapatıldı, yeniden giriş yapın',
                    'code' => $sebep?->istemciKodu() ?? 'oturum_kapatildi',
                ], 401);
            }
        }

        return $next($request);
    }
}
