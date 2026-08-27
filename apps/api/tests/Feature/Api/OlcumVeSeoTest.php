<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * ÖLÇÜM (GA4) + ÇEREZ RIZASI + SEO YÜZEYİ — 2026-08-19'da eklendi.
 *
 * ── NEDEN AYRI BİR DOSYA ─────────────────────────────────────────────────────────────────
 * `SiteIcerikTest` sayfanın NE YAZDIĞINI, `SiteGezinmeTest` NEREYE GİTTİĞİNİ kilitliyor.
 * Bu dosya üçüncü bir sözleşmeyi kilitliyor: sayfanın ARKA PLANDA NE YAPTIĞINI — hangi
 * betiği yüklediğini, kime istek gönderdiğini, arama motoruna ne söylediğini.
 *
 * ── EN KRİTİK İDDİA: RIZASIZ ÖLÇÜM YOK ───────────────────────────────────────────────────
 * Çerez Politikası ziyaretçiye şunu söylüyor: "İzin vermezseniz bu çerezler hiç yerleştirilmez
 * ve Google'a hiçbir istek gönderilmez." Bu, metinde kalan bir vaat olamaz — kod bunu YAPMAK
 * zorunda ve testin de bunu ÖLÇMESİ gerekiyor.
 *
 * Ölçüm noktası şu: sunucunun bastığı HTML'de `googletagmanager.com` adresine giden bir
 * `<script src>` BULUNMAMALI. Betik ancak `public/js/olcum.js` rıza gördükten sonra DOM'a
 * enjekte eder. Yani "rıza öncesi Google'a istek yok" iddiası, sunucu çıktısında
 * doğrulanabilir bir olgudur — tarayıcı gerektirmez.
 *
 * ⚠️ Bu testin ölçemediği şey: JS'in çalışma zamanı davranışı (rıza sonrası betiği gerçekten
 * enjekte ediyor mu). Onun kanıtı tarayıcıda DevTools → Network → "google" filtresidir ve
 * public/js/olcum.js'in belge başlığında yazılıdır. Test edilemeyeni test ediyormuş gibi
 * yapmak, olmayan bir güvence üretirdi.
 */
class OlcumVeSeoTest extends TestCase
{
    /** Ölçüm kapıları açıkken bir sayfa iste (üretim dışı ortamda varsayılan KAPALI). */
    private function olcumluSayfa(string $adres = '/'): string
    {
        config(['analitik.enabled' => true, 'analitik.measurement_id' => 'G-TEST00000']);

        return $this->get($adres)->assertOk()->getContent();
    }

    #[Test]
    public function riza_verilmeden_google_betigi_sayfaya_basilmaz(): void
    {
        $govde = $this->olcumluSayfa();

        // Kurulum VAR (ayar kanalı + kendi betiğimiz)...
        $this->assertStringContainsString('olcum-ayar', $govde);
        $this->assertStringContainsString('js/olcum.js', $govde);

        // ...ama Google'a giden bir betik YOK. Çerez Politikası'nın vaadi tam olarak budur.
        $this->assertStringNotContainsString(
            'googletagmanager.com',
            $govde,
            'Rıza alınmadan Google betiği sayfaya basılıyor — Çerez Politikası bunun aksini vaat ediyor.'
        );
    }

    #[Test]
    public function olcum_kapaliyken_hicbir_iz_basilmaz(): void
    {
        /*
         * Üç kapının ikisi burada sınanıyor (config/analitik.php): ortam kapalıysa ve kimlik
         * boşsa sayfa ölçümden HABERSİZ basılmalı. Bu, testlerin ve yerel geliştirmenin
         * gerçek GA4 mülküne veri yollamamasının garantisidir — 400 test koşusu 400 sayfa
         * görüntülemesi üretseydi rapor kullanılamaz hâle gelirdi.
         */
        config(['analitik.enabled' => false]);
        $kapali = $this->get('/')->assertOk()->getContent();
        $this->assertStringNotContainsString('olcum-ayar', $kapali);
        $this->assertStringNotContainsString('cerez-band', $kapali);

        config(['analitik.enabled' => true, 'analitik.measurement_id' => '']);
        $kimliksiz = $this->get('/')->assertOk()->getContent();
        $this->assertStringNotContainsString('olcum-ayar', $kimliksiz);
        $this->assertStringNotContainsString('cerez-band', $kimliksiz);
    }

    #[Test]
    public function cerez_bandi_kabul_ve_reddi_esit_agirlikta_sunar(): void
    {
        /*
         * KVK Kurulu'nun çerez rehberi, reddi zorlaştıran tasarımı geçerli rıza saymaz.
         * "Reddet düğmesi var mı" sorusu bir görsel tasarım sorusu gibi görünür ama HUKUKİ
         * bir şarttır: yoksa toplanan rıza geçersizdir ve ölçümün tamamı dayanaksız kalır.
         *
         * Yapısal ölçüt: iki düğme de `.dg` sınıfını taşır (aynı düğme dili) ve ret düğmesi
         * kabulden ÖNCE gelir. "Devam ederseniz kabul etmiş sayılırsınız" gibi bir ifade
         * bulunmamalı — o, rızayı sessizliğe bağlamaktır.
         */
        $govde = $this->olcumluSayfa();

        $this->assertMatchesRegularExpression('/<div id="cerez-band"/', $govde);
        $this->assertStringContainsString('id="cerez-ret"', $govde);
        $this->assertStringContainsString('id="cerez-kabul"', $govde);

        $retYeri = (int) mb_strpos($govde, 'id="cerez-ret"');
        $kabulYeri = (int) mb_strpos($govde, 'id="cerez-kabul"');
        $this->assertLessThan($kabulYeri, $retYeri, 'Ret düğmesi kabulden önce gelmeli.');

        $this->assertStringNotContainsString('kabul etmiş sayılırsınız', $govde);
    }

    #[Test]
    public function karar_verilmis_ziyaretcide_band_gizli_basilir(): void
    {
        // Titreme (FOUC) önlemesi: kararı bilen taraf sunucudur, çerez zaten istekte geliyor.
        config(['analitik.enabled' => true, 'analitik.measurement_id' => 'G-TEST00000']);

        // ⚠️ ŞİFRELENMEMİŞ çerez: rıza çerezini tarayıcıdaki JS yazar, Laravel'in imzasını
        // taşımaz (bkz. bootstrap/app.php muafiyeti). `withCookie()` kullanmak, gerçek
        // tarayıcıda çalışmayan bir kodu yeşil gösterirdi — 2026-08-28'e kadar öyle oldu.
        $govde = $this->withUnencryptedCookie((string) config('cerezler.cerez'), 'ret')
            ->get('/')->assertOk()->getContent();

        $this->assertMatchesRegularExpression(
            '/<div id="cerez-band"[^>]*\shidden/',
            $govde,
            'Tercihini bildirmiş ziyaretçiye band yeniden gösteriliyor.'
        );
    }

    #[Test]
    public function site_csp_si_olcum_kaynaklarina_izin_verir_panel_ve_api_vermez(): void
    {
        /*
         * CSP genişletilmeden GA4 ÇALIŞMAZ ve arıza SESSİZDİR: betik reddedilir, konsola bir
         * satır düşer, kimse bakmaz, rapor boş kalır. Bu test o sessiz arızayı görünür yapar.
         *
         * İkinci yarısı en az birincisi kadar önemli: genişletme YALNIZ siteye ait olmalı.
         * Panel bizim iç aracımız; kullanımını Google'a raporlamanın hiçbir gerekçesi yok ve
         * "kolay olsun" diye politikayı tek yerden gevşetmek tam da böyle sızar.
         */
        $siteCsp = (string) $this->get('/')->assertOk()->headers->get('Content-Security-Policy');

        foreach (['https://www.googletagmanager.com', 'https://*.google-analytics.com', 'https://*.analytics.google.com'] as $kaynak) {
            $this->assertStringContainsString($kaynak, $siteCsp, "Site CSP'sinde eksik ölçüm kaynağı: {$kaynak}");
        }

        // Nonce koruması gevşetilmemiş olmalı — `'unsafe-inline'` eklemek nonce'u anlamsız kılar.
        $this->assertStringNotContainsString("script-src 'self' 'unsafe-inline'", $siteCsp);

        $panelCsp = (string) $this->get('/panel/login')->headers->get('Content-Security-Policy');
        $this->assertStringNotContainsString('googletagmanager', $panelCsp, 'Panel CSP\'si Google\'a açılmış.');

        $apiCsp = (string) $this->get('/api/v1/version')->headers->get('Content-Security-Policy');
        $this->assertStringNotContainsString('googletagmanager', $apiCsp);
    }

    #[Test]
    public function referrer_policy_sitede_gevsek_panel_ve_apide_katidir(): void
    {
        /*
         * `no-referrer` sitede ölçümü körleştiriyordu (tüm trafik "doğrudan" görünür).
         * `strict-origin-when-cross-origin`: aynı kökene tam adres, dış kökene YALNIZ köken.
         * Panel ve API'de `no-referrer` KALMALI — adresleri bağlam taşıyor.
         *
         * ⚠️ API TARAFINDA BAŞARILI BİR YANIT SEÇİLDİ (`/api/v1/version`) VE BU BİR TESPİTİ
         * GİZLEMEK DEĞİL, KAPSAMI DÜRÜST TUTMAKTIR. Ölçüm sırasında görüldü ki `SecurityHeaders`
         * `api` grubuna `append` ile takılı — yani kimlik doğrulama middleware'inden ÖNCE değil,
         * SONRA çalışıyor. Sonuç: `auth:sanctum`ın fırlattığı 401 gibi HATA yanıtları güvenlik
         * başlıklarını HİÇ ALMIYOR (ölçüldü: /api/v1/auth/me → 401, Referrer-Policy = null).
         *
         * Bu, bu vardiyanın açtığı bir kusur DEĞİL, önceden beri var olan bir boşluktur ve
         * ölçüm işiyle ilgisi yok; JSON dönen bir 401'de eksik `nosniff`in pratik etkisi de
         * düşüktür. Ama middleware sırasını burada değiştirmek, bu vardiyanın kapsamı dışında
         * bir davranış değişikliğidir (öncelik listesi `ResolveTenantContext` için elle
         * ayarlanmış — dokunmak yan etki üretebilir). Bulgu PLAN.md'ye yazıldı.
         */
        $this->assertSame(
            'strict-origin-when-cross-origin',
            $this->get('/')->headers->get('Referrer-Policy')
        );
        $this->assertSame('no-referrer', $this->get('/panel/login')->headers->get('Referrer-Policy'));
        $this->assertSame('no-referrer', $this->get('/api/v1/version')->headers->get('Referrer-Policy'));
    }

    #[Test]
    public function kimlik_ve_odeme_ekranlari_dizine_kapalidir(): void
    {
        // Giriş/kayıt/ödeme sayfalarının arama sonucunda çıkmasının kimseye faydası yok;
        // `/abonelik` ve `/parola/yenile/{token}` ise bağlam taşır, dizine girmeleri zarardır.
        foreach (['/giris', '/kayit', '/parola'] as $adres) {
            $this->get($adres)
                ->assertOk()
                ->assertSee('name="robots" content="noindex,follow"', false);
        }
    }

    #[Test]
    public function genel_sayfalar_dizine_acik_ve_kanoniktir(): void
    {
        foreach (['/', '/ozellikler', '/destek', '/iletisim'] as $adres) {
            $govde = $this->get($adres)->assertOk()->getContent();

            $this->assertStringContainsString('content="index,follow', $govde, $adres.' dizine kapalı.');
            $this->assertStringContainsString('rel="canonical"', $govde, $adres.' kanonik adres taşımıyor.');
            $this->assertStringContainsString('property="og:title"', $govde, $adres.' OG başlığı taşımıyor.');
            $this->assertStringContainsString('name="description"', $govde, $adres.' meta açıklaması taşımıyor.');
        }
    }

    #[Test]
    public function gizlenen_fiyat_sayfasi_dizine_kapali_kalir(): void
    {
        // 2026-08-05 kararı: /fiyatlar rotası duruyor ama `noindex`. Layout'a `dizine` prop'u
        // eklenirken bu kararın kazara geri alınmadığını kilitler.
        $this->get('/fiyatlar')->assertOk()->assertSee('content="noindex,follow', false);
    }

    #[Test]
    public function site_haritasi_gecerli_xml_ve_noindex_sayfa_icermez(): void
    {
        $yanit = $this->get('/sitemap.xml')->assertOk();
        $xml = $yanit->getContent();

        $this->assertStringStartsWith('<?xml', $xml, 'XML bildiriminden önce çıktı sızmış.');

        $belge = new \DOMDocument;
        $this->assertTrue($belge->loadXML($xml), 'Site haritası geçerli XML değil.');

        /*
         * `/fiyatlar` haritada OLMAMALI: sayfa `noindex` taşıyor ve aynı adresi haritaya koymak
         * Google'a çelişkili iki sinyal göndermektir ("bunu indeksle" + "bunu indeksleme").
         */
        $this->assertStringNotContainsString(route('site.fiyatlar'), $xml);

        // Hukuk belgeleri haritadan gelir; yeni belge eklendiğinde elle güncelleme gerekmemeli.
        foreach (array_keys((array) config('subscription.legal_docs')) as $slug) {
            $this->assertStringContainsString(route('legal.show', $slug), $xml, "Site haritasında eksik belge: {$slug}");
        }
    }

    #[Test]
    public function robots_dosyasi_site_haritasini_duyurur_ve_ozel_alanlari_kapatir(): void
    {
        $yol = public_path('robots.txt');
        $this->assertFileExists($yol);

        $icerik = (string) file_get_contents($yol);

        $this->assertStringContainsString('Sitemap: https://sipario.com.tr/sitemap.xml', $icerik);

        foreach (['/panel', '/hesap', '/api/', '/abonelik'] as $kapali) {
            $this->assertStringContainsString('Disallow: '.$kapali, $icerik, "robots.txt {$kapali} yolunu kapatmıyor.");
        }
    }

    #[Test]
    public function llms_dosyasi_urunun_sinirlarini_da_yazar(): void
    {
        /*
         * llms.txt'in değeri, ürünün ne YAPTIĞINI değil ne YAPMADIĞINI da söylemesinde. Bir dil
         * modeline "Sipario e-fatura kesiyor mu?" diye sorulduğunda, dosyada açık bir "hayır"
         * yoksa model boşluğu tahminle doldurur ve ürünü yanlış anlatır.
         */
        $metin = $this->get('/llms.txt')->assertOk()->getContent();

        $this->assertStringContainsString('# Sipario', $metin);
        $this->assertStringContainsString('Ne yapmaz', $metin);
        $this->assertStringContainsString('e-fatura kesmez', $metin);

        // Hukuk belgeleri haritadan basılır — elle tutulan ikinci bir liste olmamalı.
        foreach ((array) config('subscription.legal_docs') as $slug => $belge) {
            $this->assertStringContainsString(route('legal.show', $slug), $metin);
        }
    }

    #[Test]
    public function yapisal_veri_yer_tutucu_kunye_basmaz(): void
    {
        /*
         * Organization şeması arama sonucunda görünür. Künye hâlâ yer tutucu olduğu için
         * `telephone`/`email` alanları BASILMAMALI — "[Telefon]" yazan bir yapısal veri,
         * Google'ın bilgi kartında görünen bir kırıklıktır.
         */
        $govde = $this->get('/')->assertOk()->getContent();

        $this->assertStringContainsString('"@type":"Organization"', $govde);
        $this->assertDoesNotMatchRegularExpression('/"telephone":"\[/', $govde);
        $this->assertDoesNotMatchRegularExpression('/"legalName":"\[/', $govde);
    }

    #[Test]
    public function donusum_dugmeleri_olcum_isareti_tasir(): void
    {
        /*
         * Ölçüm kurmanın en kolay yanılgısı: etiketi ekleyip HİÇBİR OLAY bağlamamak. O zaman
         * rapor yalnız sayfa görüntülemesi gösterir ve "kaç kişi denemeye tıkladı" sorusu
         * yine cevapsız kalır. Bu test, huninin giriş düğmesinin işaretli kaldığını kilitler.
         */
        $govde = $this->olcumluSayfa();

        $this->assertStringContainsString('data-olcum="sipario_deneme_tik"', $govde);

        // İşaretlenen her olay config'te TANIMLI olmalı — yazım hatası, GA4'te sessizce yeni
        // ve boş bir olay adı yaratır; kimse fark etmez.
        preg_match_all('/data-olcum(?:-otomatik)?="([a-z_]+)"/', $govde, $m);
        $this->assertNotEmpty($m[1]);

        foreach (array_unique($m[1]) as $olay) {
            $this->assertArrayHasKey(
                $olay,
                (array) config('analitik.olaylar'),
                "Sayfada config'de tanımlı olmayan bir ölçüm olayı var: {$olay}"
            );
        }
    }
}
