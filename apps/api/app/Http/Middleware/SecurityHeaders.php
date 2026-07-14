<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Güvenlik başlıkları (denetim bulgusu F3). API + site aynı Laravel uygulamasını paylaşacağından
 * (DECISIONS: Livewire paneli/sitesi aynı repo) bu başlıklar bugünden api yanıtlarına eklenir.
 *
 *  - X-Content-Type-Options: nosniff        → MIME tipi tahminini kapatır (JSON'u script sanmasın).
 *  - X-Frame-Options: DENY                   → clickjacking; API yanıtı çerçeveye gömülemez.
 *  - Referrer-Policy: no-referrer            → istemci Referer ile URL/token sızdırmasın.
 *  - X-Permitted-Cross-Domain-Policies: none → Flash/PDF cross-domain politikası yüklenmesin.
 *
 * HSTS burada DEĞİL: TLS sonlandırması ters vekilde (nginx/traefik) yapılır, HSTS orada verilir;
 * uygulama katmanından verilen HSTS yanlış (http) ortamda istemciyi kilitleyebilir.
 */
class SecurityHeaders
{
    /** @var array<string, string> */
    private const HEADERS = [
        'X-Content-Type-Options' => 'nosniff',
        'X-Frame-Options' => 'DENY',
        'Referrer-Policy' => 'no-referrer',
        'X-Permitted-Cross-Domain-Policies' => 'none',
    ];

    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        foreach (self::HEADERS as $name => $value) {
            $response->headers->set($name, $value);
        }

        return $response;
    }
}
