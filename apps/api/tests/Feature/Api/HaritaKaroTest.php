<?php

namespace Tests\Feature\Api;

use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * HARİTA KAROSU ARACISI (2026-09-26 saha arızası: haritada "API Key Required").
 *
 * CARTO anahtarsız karo vermeyi kesti; anahtarsız istek 200 + filigran görsel döner. Kilitlenen
 * sözleşme: anahtar YALNIZ sunucuda eklenir, karo önbelleklenir, FİLİGRAN asla önbelleğe girmez,
 * oturumsuz kimse aracıyı kullanamaz.
 */
class HaritaKaroTest extends ApiTestCase
{
    private const PNG = "\x89PNG\r\n\x1a\ngercek-karo";

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        config()->set('harita.carto_key', 'test-anahtari');
    }

    private function jeton(): string
    {
        return $this->tokenFor($this->makeTenant('harita')['patron']);
    }

    #[Test]
    public function anahtar_sunucuda_eklenir_ve_karo_doner(): void
    {
        Http::fake(['*.basemaps.cartocdn.com/*' => Http::response(self::PNG, 200, ['ETag' => '"abc"'])]);

        $yanit = $this->asToken($this->jeton())->get('/api/v1/harita/karo/light_all/12/2394/1601.png');

        $yanit->assertOk();
        $this->assertSame('image/png', $yanit->headers->get('Content-Type'));
        $this->assertSame(self::PNG, $yanit->getContent());
        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'basemaps.cartocdn.com/light_all/12/2394/1601.png')
            && str_contains($r->url(), 'key=test-anahtari'));
    }

    #[Test]
    public function ikinci_istek_cartoya_gitmez_onbellekten_gelir(): void
    {
        Http::fake(['*.basemaps.cartocdn.com/*' => Http::response(self::PNG, 200)]);
        $jeton = $this->jeton();

        $this->asToken($jeton)->get('/api/v1/harita/karo/dark_all/10/600/400@2x.png')->assertOk();
        $this->asToken($jeton)->get('/api/v1/harita/karo/dark_all/10/600/400@2x.png')->assertOk();

        Http::assertSentCount(1);
    }

    #[Test]
    public function filigran_onbellege_girmez_ve_503_doner(): void
    {
        // CARTO anahtarı reddederse 200 + "API KEY REQUIRED" görseli döner (ETag `wm-…`).
        // Önbelleğe girseydi anahtar düzeltildikten sonra da 30 gün aynı yazı görünürdü.
        Http::fakeSequence('*.basemaps.cartocdn.com/*')
            ->push('filigran', 200, ['ETag' => '"wm-da89c20e77c1-light"'])
            ->push(self::PNG, 200, ['ETag' => '"gercek"']);
        $jeton = $this->jeton();

        $this->asToken($jeton)->get('/api/v1/harita/karo/light_all/5/10/12.png')->assertStatus(503);
        $ikinci = $this->asToken($jeton)->get('/api/v1/harita/karo/light_all/5/10/12.png');

        $ikinci->assertOk();
        $this->assertSame(self::PNG, $ikinci->getContent());
    }

    #[Test]
    public function anahtar_yoksa_disari_hic_cikmaz(): void
    {
        config()->set('harita.carto_key', null);
        Http::fake();

        $this->asToken($this->jeton())->get('/api/v1/harita/karo/light_all/5/10/12.png')->assertStatus(503);

        Http::assertNothingSent();
    }

    #[Test]
    public function oturumsuz_istek_reddedilir(): void
    {
        Http::fake();

        $this->getJson('/api/v1/harita/karo/light_all/5/10/12.png')->assertUnauthorized();

        Http::assertNothingSent();
    }

    #[Test]
    public function gecersiz_stil_ve_izgara_disi_karo_404_doner(): void
    {
        Http::fake();
        $jeton = $this->jeton();

        $this->asToken($jeton)->get('/api/v1/harita/karo/voyager/5/10/12.png')->assertNotFound();
        $this->asToken($jeton)->get('/api/v1/harita/karo/light_all/2/9/1.png')->assertNotFound();
        $this->asToken($jeton)->get('/api/v1/harita/karo/light_all/5/10/12.jpg')->assertNotFound();

        Http::assertNothingSent();
    }
}
