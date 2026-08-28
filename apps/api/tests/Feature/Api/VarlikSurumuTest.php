<?php

namespace Tests\Feature\Api;

use App\Support\Varlik;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * STATİK VARLIK PARMAK İZİ — 2026-08-28'de ÜRETİMDE YAŞANAN ARIZADAN doğdu.
 *
 * ── ARIZA ────────────────────────────────────────────────────────────────────────────────
 * Canlıda ölçüldü: `https://sipario.com.tr/css/site.css` yanıtı
 * `Cache-Control: public, max-age=31536000, immutable` taşıyor ve Cloudflare'de
 * `cf-cache-status: HIT`, `Age: 168463` — 47 saatlik bayat CSS. Görünümler ise dosyayı
 * SORGUSUZ basıyordu (`asset('css/site.css')`).
 *
 * Sonuç: deploy HTML'i yeniler, CSS'i yenilemez. Ziyaretçi YENİ İŞARETLEMEYİ ESKİ BİÇEMLE
 * görür. Çerez penceresi canlıya böyle çıktı — işaretleme yeni, biçem eski, pencere biçemsiz
 * hâlde tam ekranı kapladı.
 *
 * ── BU TEST NE KİLİTLİYOR ────────────────────────────────────────────────────────────────
 * Kusur "unutulunca geri gelen" cinsten: yeni bir görünüm `asset('css/…')` yazdığı anda o sayfa
 * sessizce bayat biçemle sunulur. Bu yüzden test iki şeyi birden ölçer: (1) damganın gerçekten
 * dosyanın değişiklik zamanı olduğunu, (2) görünümlerde damgasız tek bir yerel varlık adresi
 * KALMADIĞINI — dosya adını değil, DESENİ tarayarak.
 */
class VarlikSurumuTest extends TestCase
{
    #[Test]
    public function damga_dosyanin_degisiklik_zamanidir(): void
    {
        /*
         * Damga uygulama sürümü DEĞİL, dosyanın kendi zamanıdır ve bu bilinçli: yalnız CSS
         * düzelten bir vardiya sürümü artırmayabilir (kural: kullanıcıya görünmeyen iç düzenleme
         * artış almaz) ve o gün damga sabit kalıp arıza geri gelirdi.
         */
        $url = Varlik::url('css/site.css');

        $this->assertStringContainsString('css/site.css?s=', $url);
        $this->assertStringEndsWith('?s='.dechex((int) filemtime(public_path('css/site.css'))), $url);
    }

    #[Test]
    public function olmayan_dosya_icin_de_damga_uretilir(): void
    {
        // `?s=0` basmak, ilk deployda tüm ziyaretçileri aynı bayat adrese kilitlerdi.
        $url = Varlik::url('css/hic-yok.css');

        $this->assertMatchesRegularExpression('/\?s=[0-9a-f]{8}$/', $url);
    }

    #[Test]
    public function site_ve_panel_sayfalari_damgali_varlik_basar(): void
    {
        $site = $this->get('/')->assertOk()->getContent();

        $this->assertMatchesRegularExpression('#css/site\.css\?s=[0-9a-f]+#', $site);
        $this->assertMatchesRegularExpression('#js/alpine\.js\?s=[0-9a-f]+#', $site);

        config(['analitik.enabled' => true, 'analitik.measurement_id' => 'G-TEST00000']);
        $olcumlu = $this->get('/')->assertOk()->getContent();
        $this->assertMatchesRegularExpression('#js/cerez\.js\?s=[0-9a-f]+#', $olcumlu);
        $this->assertMatchesRegularExpression('#js/olcum\.js\?s=[0-9a-f]+#', $olcumlu);
    }

    #[Test]
    public function hicbir_gorunum_damgasiz_yerel_varlik_basmaz(): void
    {
        /*
         * ⚠️ TEK DOSYA ADI YAZAN BİR BEKÇİ HER BÖLMEDE SUSAR: yarın `public/css/eposta.css`
         * eklenip `asset()` ile basılırsa aynı arıza sessizce geri gelir. Bu yüzden test dosya
         * adı değil DESEN tarar: görünümlerde `asset('css/…')` ya da `asset('js/…')` kalmamalı.
         *
         * `asset()`in kendisi yasak değildir — görsel, yazı tipi ve favicon için doğru araçtır;
         * onlar deployla birlikte DEĞİŞMEZ. Kural yalnız biçem ve betik içindir: onlar HTML ile
         * aynı sürümde olmak zorundadır.
         */
        $suclular = [];

        foreach ($this->gorunumDosyalari() as $dosya) {
            $icerik = (string) file_get_contents($dosya);
            if (preg_match('#asset\(\s*[\'"](css|js)/#', $icerik)) {
                $suclular[] = str_replace(base_path().DIRECTORY_SEPARATOR, '', $dosya);
            }
        }

        $this->assertSame(
            [],
            $suclular,
            "Damgasız biçem/betik adresi kalmış — deploy sonrası bayat CSS'e yol açar. ".
            'Bunun yerine \App\Support\Varlik::url() kullan: '.implode(', ', $suclular)
        );
    }

    /** @return list<string> */
    private function gorunumDosyalari(): array
    {
        $dosyalar = [];
        $gezgin = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator(resource_path('views'), \FilesystemIterator::SKIP_DOTS)
        );

        foreach ($gezgin as $dosya) {
            if ($dosya->isFile() && str_ends_with($dosya->getFilename(), '.blade.php')) {
                $dosyalar[] = $dosya->getPathname();
            }
        }

        return $dosyalar;
    }
}
