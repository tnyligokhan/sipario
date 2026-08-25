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
 *  - `script-src 'self' 'nonce-…'`: `'unsafe-eval'` YOK (2026-08-04, ikinci tur — csp_safe
 *    sıkılaştırması). Yalnız NONCE'lu (ya da bizim yerel dosyalarımızdan gelen) script'ler çalışır —
 *    HTML enjeksiyonuyla sızan bir `<script src="evil.tld">` ya da satır içi `<script>` NONCE'suz
 *    olduğu için yürümez; `csp_safe` (bkz. `AppServiceProvider::boot()`) `@livewireScripts`e
 *    `eval`/`new Function` içermeyen `livewire.csp.js`i bastırır, o yüzden `'unsafe-eval'`e artık
 *    gerek yok. Nonce her istekte `Vite::useCspNonce()` ile üretilir; Livewire 4 bunu KENDİLİĞİNDEN
 *    okur (`@livewireScripts`/`@livewireStyles` etiketlerine ekler, ayrı bir entegrasyon gerekmez).
 *    `public/js/alpine.js`teki globalle konuşan HER Alpine mantığı (kopyala düğmeleri, toast,
 *    üst menü kaydırma, panel satır tıklaması/firma kombosu, SSS arama, iletişim formu) gerçek
 *    `Alpine.data()` bileşenlerine taşındı — o dosyanın belge başlığında hangisinin nereden
 *    taşındığı ve doğrulamanın nasıl yapıldığı (Alpine'ın CSP değerlendiricisi Node'da izole
 *    çalıştırılıp eski/yeni ifadeler ölçüldü) tek tek yazılı.
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
        'X-Permitted-Cross-Domain-Policies' => 'none',
    ];

    /**
     * Google'ın ölçüm kaynakları. Tek yerde durur ki `script-src`/`img-src`/`connect-src`
     * üçünde birbirinden sapmasın — biri unutulduğunda ölçüm sessizce yarım çalışır ve
     * konsolda "Refused to connect" satırı, kimsenin bakmadığı bir yerde birikir.
     *
     * `www.googletagmanager.com` hem gtag.js hem GTM konteynerini sunar (ikisi de aynı köken).
     * `*.google-analytics.com` toplama uç noktasıdır; `*.analytics.google.com` ise GA4'ün
     * bölgesel toplama alanıdır ve ATLANMASI YAYGIN BİR HATADIR — GA4 isteği region1'e
     * düştüğünde `connect-src` onu tanımazsa olaylar sessizce kaybolur.
     */
    private const OLCUM_BETIK = 'https://www.googletagmanager.com';

    private const OLCUM_BAGLANTI = 'https://*.google-analytics.com https://*.analytics.google.com https://www.googletagmanager.com';

    private const OLCUM_GORSEL = 'https://*.google-analytics.com https://www.googletagmanager.com';

    /** api/* hiç HTML/JS render etmez — mobil istemciye JSON döner, aktif içerik hiç gerekmez. */
    private const API_CSP = "default-src 'none'; frame-ancestors 'none'";

    /** İç yönetim paneli — ölçülen `panel.css`te `data:` URI yok, `img-src` bu yüzden dar. */
    private const PANEL_CSP_TEMPLATE =
        "default-src 'self'; script-src 'self' 'nonce-%1\$s'; ".
        "style-src 'self' 'unsafe-inline'; img-src 'self'; font-src 'self'; connect-src 'self'; ".
        "base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'";

    /**
     * Herkese açık site — onay kutusu SVG'si `data:` URI olarak geliyor, `img-src` bu yüzden geniş.
     *
     * ── 2026-08-19 · ÖLÇÜM İÇİN GENİŞLETİLDİ ────────────────────────────────────────────────
     * Google Analytics 4 eklendi ve CSP genişletilmeden ÇALIŞMAZDI: `script-src` gtag.js'i
     * reddeder, `connect-src` toplama isteğini keser. Genişletme SİTEYE ÖZELDİR — panel ve API
     * politikaları olduğu gibi duruyor; iç aracın Google'a çıkması için bir sebep yok.
     *
     * ⚠️ `'unsafe-inline'` script için HÂLÂ YOK ve eklenmedi. Google'ın hazır parçası satır içi
     * bir blok verir; onu olduğu gibi yapıştırmak `script-src`e `'unsafe-inline'` eklemeyi
     * gerektirirdi ve o an nonce koruması TAMAMEN ANLAMSIZLAŞIRDI (tarayıcı, nonce ile
     * `'unsafe-inline'` bir aradayken ikincisini yok sayar — ama tersi değil; yani politikayı
     * gevşetmiş olurduk). Bunun yerine mantık `public/js/olcum.js`e alındı: 'self' bir dosya,
     * nonce'a bile ihtiyacı yok.
     *
     * `frame-src` EKLENMEDİ: GTM'in `<noscript><iframe>` parçası bilerek basılmıyor
     * (gerekçesi components/site/olcum.blade.php'de — rıza kapısının dışından geçerdi).
     */
    private const SITE_CSP_TEMPLATE =
        "default-src 'self'; script-src 'self' 'nonce-%1\$s' ".self::OLCUM_BETIK.'; '.
        "style-src 'self' 'unsafe-inline'; img-src 'self' data: ".self::OLCUM_GORSEL.'; '.
        "font-src 'self'; connect-src 'self' ".self::OLCUM_BAGLANTI.'; '.
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

        /*
         * ── REFERRER-POLICY YÜZEYE GÖRE AYRIŞTI (2026-08-19) ────────────────────────────────
         * Eskiden üç yüzeyde de `no-referrer`dı. API ve PANEL için doğru ve öyle kalıyor:
         * ikisinin adresleri de bağlam taşıyor (bayi kimliği, kayıt numarası) ve dış bir siteye
         * sızmalarının hiçbir karşılığı yok.
         *
         * GENEL SİTE için `no-referrer` ÖLÇÜLEBİLİR bir zarar veriyordu: tarayıcı Referer
         * başlığını hiç göndermeyince, ziyaretçinin siteye NEREDEN geldiği kaybolur ve tüm
         * trafik "doğrudan" görünür. Bu vardiyada ölçüm kurulduğuna göre, ilk günden kör bir
         * rapor üretecek bir başlıkla başlamak anlamsızdı.
         *
         * `strict-origin-when-cross-origin` tarayıcıların bugünkü VARSAYILANIDIR ve dengeyi
         * doğru kurar: aynı kökene tam adres, farklı kökene YALNIZ köken (yol ve sorgu dizesi
         * gitmez), HTTPS'ten HTTP'ye hiçbir şey. Yani "hangi siteden geldi" bilgisi korunur,
         * "hangi sayfadaydı" bilgisi dışarı çıkmaz.
         */
        $response->headers->set('Referrer-Policy', match (true) {
            $request->is('api/*'), $request->is('panel*') => 'no-referrer',
            default => 'strict-origin-when-cross-origin',
        });

        $response->headers->set('Content-Security-Policy', match (true) {
            $request->is('api/*') => self::API_CSP,
            $request->is('panel*') => sprintf(self::PANEL_CSP_TEMPLATE, $nonce),
            default => sprintf(self::SITE_CSP_TEMPLATE, $nonce),
        });

        return $response;
    }
}
