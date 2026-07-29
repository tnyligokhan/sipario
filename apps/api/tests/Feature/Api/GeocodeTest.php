<?php

namespace Tests\Feature\Api;

use App\Support\Geocoding\YandexGeocoder;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * "Adresten Konum Al" (`POST /api/v1/geocode`).
 *
 * Sınananlar: koordinat sırası (Yandex'in lng-lat tuzağı), yurt dışı adayın elenmesi, önbelleğin
 * ikinci çağrıyı sağlayıcıya GÖTÜRMEMESİ, KVKK (dışarı yalnız adres metni çıkar), arıza ile
 * "bulunamadı"nın AYRI şeyler olması, anahtarsız kurulumda dış çağrı yapılmaması ve sağlayıcı
 * değişiminin istemci sözleşmesini bozmaması.
 */
class GeocodeTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Önbellek ve hız sınırı sayaçları testler arasında taşınmasın (ikisi de cache store'da).
        Cache::flush();
    }

    /**
     * Yandex'in tek adaylı yanıtı; `pos` BOYLAM ENLEM sırasındadır.
     *
     * @return array<string, mixed>
     */
    private function yandexYaniti(string $pos = '30.7133 36.8969', string $metin = 'Türkiye, Antalya, Kepez, Bahçe Sk., 5'): array
    {
        return [
            'response' => [
                'GeoObjectCollection' => [
                    'featureMember' => [
                        [
                            'GeoObject' => [
                                'metaDataProperty' => [
                                    'GeocoderMetaData' => [
                                        'text' => $metin,
                                        'precision' => 'exact',
                                        'kind' => 'house',
                                    ],
                                ],
                                'Point' => ['pos' => $pos],
                            ],
                        ],
                    ],
                ],
            ],
        ];
    }

    private function yandexKur(): void
    {
        config()->set('geocoding.driver', 'yandex');
        config()->set('geocoding.yandex.api_key', 'test-anahtar');
    }

    #[Test]
    public function adres_adaylari_doner_ve_koordinat_sirasi_dogrudur(): void
    {
        $this->yandexKur();
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response($this->yandexYaniti())]);

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $yanit = $this->asToken($token)->postJson('/api/v1/geocode', [
            'query' => 'Bahçe Sk. no:5',
            'region' => 'Kepez',
        ]);

        $yanit->assertOk();
        $adaylar = $yanit->json('results');
        $this->assertCount(1, $adaylar);

        // TUZAK: Yandex `pos`u "lng lat" verir. Ters okunsaydı enlem 30.71 çıkar ve Antalya'daki
        // adres Mısır açıklarına düşerdi — rota sessizce saçmalardı.
        $this->assertSame(36.8969, $adaylar[0]['lat']);
        $this->assertSame(30.7133, $adaylar[0]['lng']);
        $this->assertSame('bina', $adaylar[0]['precision']);

        // "Türkiye, " ön eki her satırda tekrar edip ekranı taşırmasın diye kırpılır.
        $this->assertSame('Antalya, Kepez, Bahçe Sk., 5', $adaylar[0]['text']);
    }

    #[Test]
    public function turkiye_disina_dusen_aday_listeye_girmez(): void
    {
        $this->yandexKur();
        // "Bahçelievler" Kosova'da da var; kuryeyi 900 km öteye gönderecek adayı hiç göstermeyiz.
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response(
            $this->yandexYaniti('21.1655 42.6629', 'Kosova, Priştine, Bahçelievler')
        )]);

        $a = $this->makeTenant('a');
        $yanit = $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'Bahçelievler mah']);

        $yanit->assertOk();
        $this->assertSame([], $yanit->json('results'));
    }

    #[Test]
    public function ayni_adres_ikinci_kez_saglayiciya_gitmez(): void
    {
        $this->yandexKur();
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response($this->yandexYaniti())]);

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->asToken($token)->postJson('/api/v1/geocode', ['query' => 'Tekrar Sk. no:7'])->assertOk();
        $ikinci = $this->asToken($token)->postJson('/api/v1/geocode', ['query' => 'Tekrar Sk. no:7']);

        $ikinci->assertOk();
        $this->assertCount(1, $ikinci->json('results'));
        Http::assertSentCount(1); // ikinci çağrı önbellekten geldi — kota yakılmadı
    }

    #[Test]
    public function onbellek_kiracidan_bagimsizdir(): void
    {
        $this->yandexKur();
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response($this->yandexYaniti())]);

        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'Ortak Cad. no:1'])->assertOk();
        $bYanit = $this->asToken($this->tokenFor($b['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'Ortak Cad. no:1']);

        // Dönen şey kamuya açık coğrafi veridir, kiracıya ait hiçbir bilgi taşımaz: B aynı
        // mahalleyi sorduğunda A'nın sorgusu ona bedavaya gelir.
        $bYanit->assertOk();
        $this->assertCount(1, $bYanit->json('results'));
        Http::assertSentCount(1);
    }

    #[Test]
    public function disariya_yalnizca_adres_metni_cikar(): void
    {
        // KIRMIZI ÇİZGİ #4: müşteri adı/telefonu sınırı geçemez. Uç nokta bunları KABUL ETMEZ;
        // gövdeye konsa bile doğrulama süzer ve sağlayıcıya taşıyacak bir yol yoktur.
        $this->yandexKur();
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response($this->yandexYaniti())]);

        $a = $this->makeTenant('a');
        $this->asToken($this->tokenFor($a['patron']))->postJson('/api/v1/geocode', [
            'query' => 'Bahçe Sk. no:5',
            'region' => 'Kepez',
            'name' => 'Ayşe Kaya',
            'phone' => '+905321112233',
            'customer_id' => '018f0000-0000-7000-8000-000000000000',
        ])->assertOk();

        Http::assertSent(function ($istek) {
            $url = rawurldecode($istek->url());

            $this->assertStringContainsString('Bahçe Sk. no:5, Kepez', $url);
            $this->assertStringNotContainsString('Ayşe Kaya', $url);
            $this->assertStringNotContainsString('905321112233', $url);
            $this->assertStringNotContainsString('018f0000', $url);

            return true;
        });
    }

    #[Test]
    public function bolge_adres_metninde_zaten_varsa_tekrarlanmaz(): void
    {
        $this->yandexKur();
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response($this->yandexYaniti())]);

        $a = $this->makeTenant('a');
        $this->asToken($this->tokenFor($a['patron']))->postJson('/api/v1/geocode', [
            'query' => 'Kepez, Bahçe Sk. no:5',
            'region' => 'Kepez',
        ])->assertOk();

        Http::assertSent(function ($istek) {
            // "Kepez, Bahçe Sk. no:5, Kepez" sağlayıcının eşleşme skorunu düşürürdü.
            $this->assertStringNotContainsString('no:5, Kepez', rawurldecode($istek->url()));

            return true;
        });
    }

    /**
     * KAPI NUMARASI GERİ ÇEKİLMESİ — 2026-07-28 saha bulgusu, gerçek Yandex yanıtıyla ölçüldü:
     *
     *   "Şirinyalı Mah. 1497. Sk. No: 9 Muratpaşa/Antalya"  → found=0
     *   "Şirinyalı Mah. 1497. Sok. Antalya"                 → found=1  (sokak VAR)
     *
     * Yandex Türkiye'de bina numarasını KATI eşleştiriyor: numara veritabanında yoksa sokağa
     * düşmüyor, sıfır dönüyor. Kullanıcıya "bu adres bulunamadı" demek yanlış — adres doğru,
     * eksik olan sağlayıcının bina verisi.
     */
    #[Test]
    public function kapi_numarasi_bulunamayinca_sokaga_dusulur(): void
    {
        $this->yandexKur();
        Http::fake(['geocode-maps.yandex.ru/*' => Http::sequence()
            // 1) Tam sorgu: Yandex hiçbir şey bulamıyor.
            ->push(['response' => ['GeoObjectCollection' => ['featureMember' => []]]])
            // 2) Numarasız sorgu: sokak bulunuyor (Yandex "exact" diyor).
            ->push($this->yandexYaniti('30.73490 36.86318', 'Türkiye, Antalya, Muratpaşa, Şirinyalı Mah., 1497. Sok.'))]);

        $a = $this->makeTenant('a');
        $yanit = $this->asToken($this->tokenFor($a['patron']))->postJson('/api/v1/geocode', [
            'query' => 'Şirinyalı Mah. 1497. Sk. No: 9 Muratpaşa/Antalya',
        ]);

        $yanit->assertOk();
        $yanit->assertJsonPath('results.0.lat', 36.86318);
        // Kesinlik ZORLA düşürülür: kapı numarası artık sorgunun parçası değil. Yandex "exact"
        // dese bile bunu "bina" diye sunmak, kuryenin güvendiği bir yalan olurdu.
        $yanit->assertJsonPath('results.0.precision', 'sokak');

        Http::assertSentCount(2);
    }

    #[Test]
    public function numarasiz_adres_ikinci_kez_sorulmaz(): void
    {
        // Atılacak bir kapı numarası yoksa aynı metni tekrar sormak boşuna kota yakar.
        $this->yandexKur();
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response([
            'response' => ['GeoObjectCollection' => ['featureMember' => []]],
        ])]);

        $a = $this->makeTenant('a');
        $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'Şirinyalı Mah., Muratpaşa'])
            ->assertOk()
            ->assertJsonPath('results', []);

        Http::assertSentCount(1);
    }

    #[Test]
    public function sokak_adindaki_sayi_korunur(): void
    {
        // Türkiye'de sokaklar numaralıdır ("1497. Sok."). "Bütün sayıları at" demek sokağın
        // kendisini silmek olurdu; yalnız AÇIKÇA kapı/daire olduğu yazan biçimler atılır.
        $this->assertSame(
            'Şirinyalı Mah. 1497. Sk. Muratpaşa/Antalya',
            YandexGeocoder::kapiNumarasiniAt('Şirinyalı Mah. 1497. Sk. No: 9 Muratpaşa/Antalya')
        );

        // İlçe adı numaranın ardından geliyor ve KORUNMALI — yutulursa sorgu daha da bozulur.
        $this->assertStringContainsString(
            'Konyaaltı',
            (string) YandexGeocoder::kapiNumarasiniAt('Atatürk Cad. No 7-B Kat 2 Konyaaltı')
        );

        // Daire/blok ekleri de atılır; "daire" için kısa alternatif ("d") önce eşleşip
        // geriye "aire 5" bırakmamalı.
        $this->assertSame(
            'Lara Cad, Muratpaşa',
            YandexGeocoder::kapiNumarasiniAt('Lara Cad. No:12/A Daire 5, Muratpaşa')
        );

        // Atılacak bir şey yoksa null (ikinci sorgu koşmasın).
        $this->assertNull(YandexGeocoder::kapiNumarasiniAt('1497. Sok., Antalya'));
    }

    #[Test]
    public function sonuc_bulunamamasi_ariza_degildir(): void
    {
        $this->yandexKur();
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response([
            'response' => ['GeoObjectCollection' => ['featureMember' => []]],
        ])]);

        $a = $this->makeTenant('a');
        $yanit = $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'zzz qqq www']);

        // 200 + boş liste: kullanıcı adresini düzeltip tekrar dener. 503 deseydik "servis bozuk"
        // derdik — oysa bozuk olan adres metniydi.
        $yanit->assertOk();
        $this->assertSame([], $yanit->json('results'));
    }

    #[Test]
    public function saglayici_arizasi_503_ve_notr_mesaj_dondurur(): void
    {
        $this->yandexKur();
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response('kota doldu: anahtar xyz', 403)]);

        $a = $this->makeTenant('a');
        $yanit = $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'Bahçe Sk. no:5']);

        $yanit->assertStatus(503);
        $this->assertSame([], $yanit->json('results'));

        // Sağlayıcının ham gerekçesi (anahtar/kota) İSTEMCİYE SIZMAZ — log'da durur.
        $mesaj = (string) $yanit->json('message');
        $this->assertStringNotContainsString('anahtar xyz', $mesaj);
        $this->assertNotSame('', $mesaj);
    }

    #[Test]
    public function ariza_onbelleklenmez_sonraki_deneme_gercekten_gider(): void
    {
        $this->yandexKur();
        // Aynı adres iki kez sorulur: ilkinde sağlayıcı düşer, ikincisinde ayağa kalkar.
        Http::fake(['geocode-maps.yandex.ru/*' => Http::sequence()
            ->pushStatus(500)
            ->push($this->yandexYaniti())]);

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->asToken($token)->postJson('/api/v1/geocode', ['query' => 'Geçici Sk. no:9'])
            ->assertStatus(503);

        $ikinci = $this->asToken($token)->postJson('/api/v1/geocode', ['query' => 'Geçici Sk. no:9']);

        // Geçici arıza kalıcı "bu adres bulunamaz" haline gelmemeli.
        $ikinci->assertOk();
        $this->assertCount(1, $ikinci->json('results'));
    }

    #[Test]
    public function anahtar_yoksa_dis_cagri_yapilmaz(): void
    {
        config()->set('geocoding.driver', 'yandex');
        config()->set('geocoding.yandex.api_key', ''); // anahtar henüz alınmamış kurulum
        Http::fake();

        $a = $this->makeTenant('a');
        $yanit = $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'Bahçe Sk. no:5']);

        $yanit->assertStatus(503);
        Http::assertNothingSent();
    }

    #[Test]
    public function google_surucusu_ayni_sozlesmeyi_verir(): void
    {
        // Sağlayıcı geçişi bir env satırıdır: istemci sözleşmesi (text/lat/lng/precision) aynı
        // kalır, mobil taraf güncellenmez.
        config()->set('geocoding.driver', 'google');
        config()->set('geocoding.google.api_key', 'g-anahtar');
        Http::fake(['maps.googleapis.com/*' => Http::response([
            'status' => 'OK',
            'results' => [[
                'formatted_address' => 'Bahçe Sk. No:5, Kepez/Antalya',
                'geometry' => [
                    'location' => ['lat' => 36.8969, 'lng' => 30.7133],
                    'location_type' => 'ROOFTOP',
                ],
            ]],
        ])]);

        $a = $this->makeTenant('a');
        $yanit = $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'Bahçe Sk. no:5']);

        $yanit->assertOk();
        $yanit->assertJsonPath('results.0.lat', 36.8969);
        $yanit->assertJsonPath('results.0.lng', 30.7133);
        $yanit->assertJsonPath('results.0.precision', 'bina');
    }

    #[Test]
    public function google_kismi_eslesmeyi_bina_diye_sunmaz(): void
    {
        // Yandex'te kapı numarası bulunamayınca sıfır sonuç gelir ve ikinci bir sorgu koşarız.
        // Google aynı durumda sokağı döner ve kaydı `partial_match: true` diye işaretler —
        // ama `location_type` yine "ROOFTOP" olabilir. Bayrağı yok sayarsak kuryeye
        // "bina kesinliğinde" derdik; oysa istenen kapı DEĞİL, sokak bulundu.
        config()->set('geocoding.driver', 'google');
        config()->set('geocoding.google.api_key', 'g-anahtar');
        Http::fake(['maps.googleapis.com/*' => Http::response([
            'status' => 'OK',
            'results' => [[
                'formatted_address' => '1497. Sk., Muratpaşa/Antalya',
                'partial_match' => true,
                'geometry' => [
                    'location' => ['lat' => 36.8600, 'lng' => 30.7300],
                    'location_type' => 'ROOFTOP',
                ],
            ]],
        ])]);

        $a = $this->makeTenant('a');
        $yanit = $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => '1497. Sk. No: 9 Muratpaşa/Antalya']);

        $yanit->assertOk();
        $yanit->assertJsonPath('results.0.precision', 'sokak');
        // Aday DÜŞMEZ — yaklaşık olması onu değersiz yapmaz, yalnız dürüstçe etiketlenir.
        $yanit->assertJsonPath('results.0.lat', 36.86);
    }

    #[Test]
    public function google_zero_results_ariza_degildir(): void
    {
        config()->set('geocoding.driver', 'google');
        config()->set('geocoding.google.api_key', 'g-anahtar');
        Http::fake(['maps.googleapis.com/*' => Http::response(['status' => 'ZERO_RESULTS', 'results' => []])]);

        $a = $this->makeTenant('a');
        $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'zzz qqq www'])
            ->assertOk()
            ->assertJsonPath('results', []);
    }

    #[Test]
    public function google_200_donup_reddedebilir(): void
    {
        // Google hatayı HTTP koduyla değil gövdedeki `status` ile bildirir: 200 + REQUEST_DENIED
        // "başarılı" sayılsaydı kullanıcıya sessizce boş liste gösterirdik.
        config()->set('geocoding.driver', 'google');
        config()->set('geocoding.google.api_key', 'g-anahtar');
        Http::fake(['maps.googleapis.com/*' => Http::response([
            'status' => 'REQUEST_DENIED',
            'error_message' => 'The provided API key is invalid.',
        ], 200)]);

        $a = $this->makeTenant('a');
        $yanit = $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'Bahçe Sk. no:5']);

        $yanit->assertStatus(503);
        $this->assertStringNotContainsString('API key', (string) $yanit->json('message'));
    }

    #[Test]
    public function kisa_sorgu_reddedilir_ve_saglayiciya_gitmez(): void
    {
        $this->yandexKur();
        Http::fake();

        $a = $this->makeTenant('a');
        $this->asToken($this->tokenFor($a['patron']))
            ->postJson('/api/v1/geocode', ['query' => 'ab'])
            ->assertStatus(422);

        Http::assertNothingSent();
    }

    #[Test]
    public function gunluk_tavan_asilinca_429_doner(): void
    {
        $this->yandexKur();
        config()->set('geocoding.daily_limit', 2);
        Http::fake(['geocode-maps.yandex.ru/*' => Http::response($this->yandexYaniti())]);

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // Sınır KİRACI başına: aynı bayinin farklı sorguları aynı kotayı paylaşır.
        $this->asToken($token)->postJson('/api/v1/geocode', ['query' => 'Kota Sk. no:1'])->assertOk();
        $this->asToken($token)->postJson('/api/v1/geocode', ['query' => 'Kota Sk. no:2'])->assertOk();
        $this->asToken($token)->postJson('/api/v1/geocode', ['query' => 'Kota Sk. no:3'])
            ->assertStatus(429);
    }

    #[Test]
    public function oturumsuz_istek_401_alir(): void
    {
        $this->yandexKur();
        Http::fake();

        $this->postJson('/api/v1/geocode', ['query' => 'Bahçe Sk. no:5'])->assertUnauthorized();
        Http::assertNothingSent();
    }
}
