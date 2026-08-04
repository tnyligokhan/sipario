<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Vite;
use Symfony\Component\HttpFoundation\Response;

/**
 * Güvenlik başlıkları (denetim bulgusu F3 + güvenlik/KVKK denetimi 2026-08-04: CSP). API + site aynı
 * Laravel uygulamasını paylaşacağından (DECISIONS: Livewire paneli/sitesi aynı repo) bu başlıklar
 * bugünden api yanıtlarına eklenir.
 *
 *  - X-Content-Type-Options: nosniff        → MIME tipi tahminini kapatır (JSON'u script sanmasın).
 *  - X-Frame-Options: DENY                   → clickjacking; yanıt çerçeveye gömülemez (CSP
 *    `frame-ancestors`in eski tarayıcı karşılığı — ikisi birlikte verilir, biri diğerini geçersiz
 *    kılmaz).
 *  - Referrer-Policy: no-referrer            → istemci Referer ile URL/token sızdırmasın.
 *  - X-Permitted-Cross-Domain-Policies: none → Flash/PDF cross-domain politikası yüklenmesin.
 *
 * HSTS burada DEĞİL: TLS sonlandırması ters vekilde (nginx/traefik) yapılır, HSTS orada verilir;
 * uygulama katmanından verilen HSTS yanlış (http) ortamda istemciyi kilitleyebilir.
 *
 * CONTENT-SECURITY-POLICY (2026-08-04 güvenlik denetimi — daha önce hiç yoktu, tek gerçek boşluktu):
 * ölçülerek yazıldı, tahmin edilmedi (bkz. render edilen sayfalardaki kaynak taraması). Üç ayrı
 * politika — sayfa render etmeyen `api/*`in HTML/JS'e hiç ihtiyacı yok, yalnız `default-src 'none'`
 * yeterli; SİTE (herkese açık, Alpine kopyala-yapıştır düğmeleri `navigator`/`window` globaline
 * erişiyor) ile PANEL (iç araç, ölçülen CSS'inde `data:` URI YOK) arasında da gerçek bir fark var.
 *
 *  - `script-src 'self' 'nonce-…'`: yalnız NONCE'lu (ya da bizim yerel dosyalarımızdan gelen)
 *    script'ler çalışır — HTML enjeksiyonuyla sızan bir `<script src="evil.tld">` ya da satır içi
 *    `<script>` NONCE'suz olduğu için yürümez. Nonce her istekte `Vite::useCspNonce()` ile üretilir;
 *    Livewire 4 bunu KENDİLİĞİNDEN okur (`@livewireScripts`/`@livewireStyles` etiketlerine ekler,
 *    ayrı bir entegrasyon gerekmez).
 *  - `'unsafe-eval'` BİLİNÇLİ TUTULDU (ideal değil, ama ÖLÇÜLMÜŞ bir kırılmayı önlüyor): Livewire'ın
 *    `csp_safe` modu (Alpine'ın eval'siz CSP derlemesi, `livewire.csp.js` — `grep` ile doğrulandı:
 *    `new Function(`/`eval(` SIFIR) üç yerde KIRARDI — `livewire/site/{odeme,register,subscribe}
 *    .blade.php`taki "kopyala" düğmeleri `@click="navigator.clipboard?.writeText(...); window
 *    .dispatchEvent(...)"` yazıyor ve Alpine'ın CSP değerlendiricisi `globalThis`in HER üyesini
 *    (`navigator`, `window`, ...) karaliste tutup "Accessing global variables is prohibited in the
 *    CSP build" fırlatıyor (kaynak: `livewire.csp.js`, `checkForDangerousValues`). Bu üç düğme IBAN/
 *    firma kodu kopyalama gibi gerçek işlevdir — sessizce kırmak "yalnız satır ekle" bir güvenlik
 *    görevinin sınırını aşardı. Doğru çözüm o üç `@click` ifadesini `Alpine.data(...)` içindeki bir
 *    METODA taşımaktır (ifade o zaman yalnız `kopyala(...)` çağırır, `navigator`/`window`'a asla
 *    DEĞER olarak dokunmaz) — bu, uygulama kodunu değiştirir ve SONRAKİ İŞ olarak bırakıldı.
 *  - `style-src 'self' 'unsafe-inline'`: 54 görünüm dosyasında (grafik çubuk/çizgi/ısı haritası
 *    genişlikleri, ikon rengi, modal genişliği gibi VERİDEN türeyen değerler) satır içi `style="…"`
 *    kullanılıyor — nonce yalnız `<style>` ETİKETİNİ kapsar, `style=""` ÖZNİTELİĞİNİ kapsamaz (CSP3
 *    `style-src-attr`), bu yüzden tek pratik seçenek `'unsafe-inline'`dir. Artan riski `script-src`
 *    kapatıyor: bir saldırgan HTML enjekte etse bile (bugünkü taramada böyle bir yol bulunamadı) en
 *    fazla stil bozar, kod ÇALIŞTIRAMAZ.
 *  - `img-src`: SİTE `data:` de alır (checkbox'ın SVG onay işareti `site.css`te `background:…
 *    url("data:image/svg+xml,…")` — ÖLÇÜLDÜ, `panel.css`te SIFIR `data:` kullanımı) — PANEL bu
 *    yüzden yalnız `'self'`.
 *  - `connect-src 'self'`: Livewire'ın kendi AJAX turu (`/livewire/update`) aynı köken; ölçülen hiçbir
 *    view dış bir `fetch`/`XHR` yapmıyor.
 *  - `font-src 'self'`: fontlar (Sora/Hanken Grotesk) YERELDEN (`/fonts/*.woff2`) — Google Fonts CDN'i
 *    yok (kod yorumunda da yazılı: "Google Fonts'a çıkış YOK").
 *  - `base-uri 'self'` + `form-action 'self'`: `<base>` etiketi ele geçirme ve form'un başka bir
 *    kökene POST edilmesi engellenir.
 *  - `object-src 'none'`: Flash/eklenti yüzeyi hiç kullanılmıyor.
 *  - `frame-ancestors 'none'`: `X-Frame-Options: DENY`in CSP3 karşılığı, aynı korumayı verir.
 *
 * NEDEN RAPOR KİPİ DEĞİL, DOĞRUDAN ZORLAYICI: site henüz CANLI DEĞİL (iyzico prod anahtarı, mağaza
 * başvurusu, hukuk onayı bekliyor — PLAN.md), yani gerçek kullanıcı trafiği kırılmıyor; politika
 * TAHMİNLE değil sayfalar/CSS TARANARAK yazıldı (yukarıdaki kaynak listesi) ve tek bilinen kırılma
 * noktası (`unsafe-eval`) BİLEREK açık bırakıldı. Rapor kipi, "bilmediğimizi öğrenmek" için vardır;
 * burada ölçüm zaten yapıldı — Report-Only'e geçmek doğrulanmış bir korumayı ertelemek olurdu.
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

    /** api/* hiç HTML/JS render etmez — mobil istemciye JSON döner, aktif içerik hiç gerekmez. */
    private const API_CSP = "default-src 'none'; frame-ancestors 'none'";

    /** İç yönetim paneli — ölçülen `panel.css`te `data:` URI yok, `img-src` bu yüzden dar. */
    private const PANEL_CSP_TEMPLATE =
        "default-src 'self'; script-src 'self' 'nonce-%1\$s' 'unsafe-eval'; ".
        "style-src 'self' 'unsafe-inline'; img-src 'self'; font-src 'self'; connect-src 'self'; ".
        "base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'";

    /** Herkese açık site — onay kutusu SVG'si `data:` URI olarak geliyor, `img-src` bu yüzden geniş. */
    private const SITE_CSP_TEMPLATE =
        "default-src 'self'; script-src 'self' 'nonce-%1\$s' 'unsafe-eval'; ".
        "style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; ".
        "base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'";

    public function handle(Request $request, Closure $next): Response
    {
        // Nonce İSTEK BAŞINA bir kez, view render edilmeden ÖNCE üretilir: Livewire 4
        // `@livewireScripts`/`@livewireStyles` bunu kendiliğinden okuyup enjekte ettiği script/style
        // etiketlerine ekler (`Vite::cspNonce()`); biz aşağıda AYNI değeri header'a yazarız.
        $nonce = $request->is('api/*') ? null : Vite::useCspNonce();

        $response = $next($request);

        foreach (self::HEADERS as $name => $value) {
            $response->headers->set($name, $value);
        }

        $response->headers->set('Content-Security-Policy', match (true) {
            $request->is('api/*') => self::API_CSP,
            $request->is('panel*') => sprintf(self::PANEL_CSP_TEMPLATE, $nonce),
            default => sprintf(self::SITE_CSP_TEMPLATE, $nonce),
        });

        return $response;
    }
}
