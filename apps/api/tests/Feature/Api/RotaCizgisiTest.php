<?php

namespace Tests\Feature\Api;

use App\Support\Route\PolylineCozucu;
use App\Support\Route\RotaException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsRouteStops;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * YOL ÇİZGİSİ — `POST /api/v1/rota/cizgi` (kullanıcı isteği 2026-09-29: "konumlar arası yolu
 * kuşbakışı çiziyor, yollardan çizmeli").
 *
 * Sınananlar: çizgi Google'dan verilen SIRAYLA alınır ve çözülür, aynı dizi ikinci kez Google'a
 * GİTMEZ, arıza önbelleğe GİRMEZ, kurulum yoksa dürüst 503, uzun rota parçalanır ve birleşim
 * noktası çoğalmaz, kontör DÜŞMEZ, dışarıya yalnız koordinat çıkar.
 */
class RotaCizgisiTest extends ApiTestCase
{
    use BuildsRouteStops;
    use BuildsSyncEvents;

    /** Google'ın belgelerindeki örnek: (38.5,-120.2) (40.7,-120.95) (43.252,-126.453). */
    private const ORNEK_KODLU = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

    private const KEPEZ = [36.9125, 30.6689];

    private const MURATPASA = [36.8841, 30.7056];

    private const LARA = [36.8632, 30.7809];

    protected function setUp(): void
    {
        parent::setUp();
        config()->set('rota.surucu', 'google');
        config()->set('rota.google.api_key', 'test-anahtari');
        config()->set('rota.google.base_url', 'https://routes.googleapis.com/directions/v2:computeRoutes');
    }

    private function googleBasarili(): void
    {
        Http::fake(['routes.googleapis.com/*' => Http::response([
            'routes' => [['polyline' => ['encodedPolyline' => self::ORNEK_KODLU]]],
        ])]);
    }

    /** @return array{0: string, 1: array<string, string>} token + ad → sipariş kimliği */
    private function ucDurak(): array
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        return [$token, $this->siparisleriKur($token, [
            'lara' => self::LARA,
            'kepez' => self::KEPEZ,
            'muratpasa' => self::MURATPASA,
        ])];
    }

    #[Test]
    public function polyline_cozucu_google_ornegini_dogru_cozer(): void
    {
        $this->assertSame(
            [[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]],
            PolylineCozucu::coz(self::ORNEK_KODLU),
        );
        $this->assertSame([], PolylineCozucu::coz(''));
    }

    #[Test]
    public function polyline_cozucu_yarim_girdide_istisna_atar(): void
    {
        // Yarım bir çizgi haritada yanlış yere giden bir yol çizer — hiç çizgi olmaması iyidir.
        $this->expectException(RotaException::class);
        PolylineCozucu::coz('_p~iF~ps|U_');
    }

    #[Test]
    public function cizgi_verilen_sirayla_alinir_ve_cozulmus_doner(): void
    {
        $this->googleBasarili();
        [$token, $s] = $this->ucDurak();

        $yanit = $this->asToken($token)->postJson('/api/v1/rota/cizgi', [
            'order_ids' => [$s['kepez'], $s['muratpasa'], $s['lara']],
        ]);

        $yanit->assertOk();
        $this->assertSame([[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]], $yanit->json('noktalar'));
        // Çizginin dayandığı duraklar, İSTENEN SIRAYLA — istemci pinlerle karşılaştırır.
        $this->assertSame([self::KEPEZ, self::MURATPASA, self::LARA], $yanit->json('duraklar'));

        Http::assertSent(function (Request $istek) {
            $govde = $istek->data();

            return $istek->hasHeader('X-Goog-FieldMask', 'routes.polyline.encodedPolyline')
                && data_get($govde, 'origin.location.latLng.latitude') === self::KEPEZ[0]
                && data_get($govde, 'destination.location.latLng.latitude') === self::LARA[0]
                && count($govde['intermediates']) === 1
                // SIRALAMA YAPMAZ: sıra istemcinindir.
                && ! array_key_exists('optimizeWaypointOrder', $govde);
        });
    }

    #[Test]
    public function ayni_dizi_ikinci_kez_googlea_gitmez(): void
    {
        $this->googleBasarili();
        [$token, $s] = $this->ucDurak();
        $govde = ['order_ids' => [$s['lara'], $s['muratpasa'], $s['kepez']]];

        $this->asToken($token)->postJson('/api/v1/rota/cizgi', $govde)->assertOk();
        $this->asToken($token)->postJson('/api/v1/rota/cizgi', $govde)->assertOk();

        Http::assertSentCount(1);
    }

    #[Test]
    public function sira_degisince_yeni_cizgi_istenir(): void
    {
        $this->googleBasarili();
        [$token, $s] = $this->ucDurak();

        $this->asToken($token)->postJson('/api/v1/rota/cizgi', [
            'order_ids' => [$s['lara'], $s['muratpasa'], $s['kepez']],
        ])->assertOk();
        $this->asToken($token)->postJson('/api/v1/rota/cizgi', [
            'order_ids' => [$s['kepez'], $s['muratpasa'], $s['lara']],
        ])->assertOk();

        Http::assertSentCount(2);
    }

    #[Test]
    public function ariza_503_doner_ve_onbellege_girmez(): void
    {
        Http::fake(['routes.googleapis.com/*' => Http::sequence()
            ->push(['error' => ['status' => 'INTERNAL']], 500)
            ->push(['routes' => [['polyline' => ['encodedPolyline' => self::ORNEK_KODLU]]]])]);
        [$token, $s] = $this->ucDurak();
        $govde = ['order_ids' => [$s['lara'], $s['kepez']]];

        $this->asToken($token)->postJson('/api/v1/rota/cizgi', $govde)->assertStatus(503);
        // Arıza hatırlanmasaydı ikinci istek de 503 olurdu (bir gün boyunca düz çizgi).
        $this->asToken($token)->postJson('/api/v1/rota/cizgi', $govde)->assertOk();

        Http::assertSentCount(2);
    }

    #[Test]
    public function google_kapaliysa_durust_503_ve_dis_cagri_yok(): void
    {
        // Bayi sıralamada Google'ı kapattıysa çizgi için de paralı çağrı yapılmaz.
        config()->set('rota.surucu', 'yakin-komsu');
        Http::fake();
        [$token, $s] = $this->ucDurak();

        $this->asToken($token)->postJson('/api/v1/rota/cizgi', [
            'order_ids' => [$s['lara'], $s['kepez']],
        ])->assertStatus(503)->assertJsonPath('message', 'Yol çizgisi bu kurulumda tanımlı değil.');

        Http::assertNothingSent();
    }

    #[Test]
    public function konumlu_durak_ikiden_azsa_bos_cizgi_ve_dis_cagri_yok(): void
    {
        Http::fake();
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $s = $this->siparisleriKur($token, ['lara' => self::LARA]);

        // İkinci kimlik rastgele (var olmayan) — tek konumlu durak kalır.
        $this->asToken($token)->postJson('/api/v1/rota/cizgi', [
            'order_ids' => [$s['lara'], '0192d5a4-0000-7000-8000-000000000000'],
        ])->assertOk()->assertJsonPath('noktalar', []);

        Http::assertNothingSent();
    }

    #[Test]
    public function uzun_rota_parcalanir_ve_birlesim_noktasi_cogalmaz(): void
    {
        // 28 durak: ilk istek 27 nokta (başlangıç + 25 ara + hedef), ikincisi kalan 2 nokta —
        // ikinci parça birincinin SON noktasından başlar ki çizgi kopmasın.
        Http::fake(['routes.googleapis.com/*' => Http::sequence()
            ->push(['routes' => [['polyline' => ['encodedPolyline' => self::ORNEK_KODLU]]]])
            ->push(['routes' => [['polyline' => ['encodedPolyline' => self::ORNEK_KODLU]]]])]);
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $noktalar = [];
        for ($i = 0; $i < 28; $i++) {
            $noktalar['d'.$i] = [36.80 + $i * 0.002, 30.60 + $i * 0.002];
        }
        $s = $this->siparisleriKur($token, $noktalar);

        $yanit = $this->asToken($token)->postJson('/api/v1/rota/cizgi', ['order_ids' => array_values($s)]);

        $yanit->assertOk();
        Http::assertSentCount(2);
        // Her parça 3 nokta çözer; birleşimde bir nokta atılır → 3 + 2.
        $this->assertCount(5, $yanit->json('noktalar'));
        $this->assertCount(28, $yanit->json('duraklar'));
    }

    #[Test]
    public function kontor_dusmez(): void
    {
        $this->googleBasarili();
        $a = $this->makeTenant('a');
        $this->setRouteCredits($a['tenant']->id, 7);
        $token = $this->tokenFor($a['patron']);
        $s = $this->siparisleriKur($token, ['lara' => self::LARA, 'kepez' => self::KEPEZ]);

        $this->asToken($token)->postJson('/api/v1/rota/cizgi', ['order_ids' => array_values($s)])->assertOk();

        $this->assertSame(7, $this->routeCredits($a['tenant']->id), 'çizim bir sıralama değildir');
    }

    #[Test]
    public function disariya_yalniz_koordinat_cikar(): void
    {
        // Kırmızı çizgi #4: müşteri adı, adres metni, sipariş kimliği Google'a GİTMEZ.
        $this->googleBasarili();
        [$token, $s] = $this->ucDurak();

        $this->asToken($token)->postJson('/api/v1/rota/cizgi', [
            'order_ids' => [$s['lara'], $s['kepez']],
        ])->assertOk();

        Http::assertSent(function (Request $istek) use ($s) {
            $ham = json_encode($istek->data()) ?: '';

            return ! str_contains($ham, 'Müşteri')
                && ! str_contains($ham, 'Mah.')
                && ! str_contains($ham, $s['lara']);
        });
    }

    #[Test]
    public function tek_siparis_ya_da_bozuk_kimlik_422(): void
    {
        Http::fake();
        [$token, $s] = $this->ucDurak();

        $this->asToken($token)->postJson('/api/v1/rota/cizgi', ['order_ids' => [$s['lara']]])
            ->assertStatus(422);
        $this->asToken($token)->postJson('/api/v1/rota/cizgi', ['order_ids' => [$s['lara'], 'x']])
            ->assertStatus(422);
        $this->asToken($token)->postJson('/api/v1/rota/cizgi', ['order_ids' => [$s['lara'], $s['lara']]])
            ->assertStatus(422);

        Http::assertNothingSent();
    }
}
