<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * "Canlı kurye konumu" (`POST /api/v1/locations/heartbeat`, `GET /api/v1/locations/live`).
 *
 * Sınananlar: kalp atışının GEÇMİŞ BİRİKTİRMEMESİ (kullanıcı başına tek satır — KVKK veri
 * minimizasyonunun asıl kanıtı), aralık doğrulaması, listeyi yalnız patronun okuyabilmesi,
 * tazelik bayrağı ile pencere dışı eleme farkı ve yanıtın mobil sözleşmeyle birebir uyuşması.
 */
class LiveLocationTest extends ApiTestCase
{
    /** Tasarım referansı: Antalya/Kepez civarı gerçekçi bir nokta. */
    private const KEPEZ = [36.9125, 30.6689];

    protected function setUp(): void
    {
        parent::setUp();

        // Hız sınırı sayaçları cache store'dadır ve testler arasında taşınırsa 6 atışlık kota
        // önceki testin atışlarıyla dolar (GeocodeTest'teki aynı gerekçe).
        Cache::flush();
    }

    /** Konum satırının kaç tane olduğunu owner (RLS-üstü) bağlamda sayar. */
    private function satirSayisi(): int
    {
        return (int) $this->asOwner(fn () => DB::table('courier_locations')->count());
    }

    /** Owner bağlamında tek satırı okur (RLS'ten bağımsız gerçek). */
    private function satir(User $kullanici): ?object
    {
        return $this->asOwner(fn () => DB::table('courier_locations')
            ->where('user_id', $kullanici->id)->first());
    }

    /**
     * Verilen kullanıcı için doğrudan (kalp atışı akışını atlayarak) bir konum satırı yazar.
     * Tazelik testleri için gerekli: `reported_at` sunucu saatidir, istemci gönderemez — geçmişe
     * ait bir damgayı ancak DB'ye doğrudan yazarak kurabiliriz.
     */
    private function konumYaz(User $kullanici, CarbonImmutable $ne): void
    {
        $this->asOwner(fn () => DB::table('courier_locations')->updateOrInsert(
            ['user_id' => $kullanici->id],
            [
                'tenant_id' => $kullanici->tenant_id,
                'lat' => self::KEPEZ[0],
                'lng' => self::KEPEZ[1],
                'accuracy_m' => 12.5,
                'reported_at' => $ne,
            ],
        ));
    }

    #[Test]
    public function kalp_atisi_204_doner_ve_satiri_yazar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['kurye']);

        $yanit = $this->asToken($token)->postJson('/api/v1/locations/heartbeat', [
            'lat' => self::KEPEZ[0],
            'lng' => self::KEPEZ[1],
            'accuracy_m' => 12.5,
        ]);

        $yanit->assertNoContent();

        $satir = $this->satir($a['kurye']);
        $this->assertNotNull($satir);
        $this->assertSame($a['tenant']->id, $satir->tenant_id);
        $this->assertEqualsWithDelta(self::KEPEZ[0], (float) $satir->lat, 0.000001);
        $this->assertEqualsWithDelta(self::KEPEZ[1], (float) $satir->lng, 0.000001);
        $this->assertEqualsWithDelta(12.5, (float) $satir->accuracy_m, 0.000001);
    }

    #[Test]
    public function ikinci_kalp_atisi_ayni_satiri_gunceller_gecmis_biriktirmez(): void
    {
        // KVKK veri minimizasyonunun ASIL testi: satır sayısı artmıyorsa iz arşivi oluşmuyor.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['kurye']);

        $this->asToken($token)->postJson('/api/v1/locations/heartbeat', [
            'lat' => self::KEPEZ[0], 'lng' => self::KEPEZ[1], 'accuracy_m' => 30.0,
        ])->assertNoContent();
        $this->assertSame(1, $this->satirSayisi());

        $this->asToken($token)->postJson('/api/v1/locations/heartbeat', [
            'lat' => 36.8841, 'lng' => 30.7056, 'accuracy_m' => 8.0,
        ])->assertNoContent();

        $this->assertSame(1, $this->satirSayisi(), 'Kalp atışı geçmiş satırı BİRİKTİRMEMELİ.');

        // Yeni değerler eskisini EZMİŞ olmalı (ON CONFLICT DO UPDATE dalı gerçekten koşuyor).
        $satir = $this->satir($a['kurye']);
        $this->assertNotNull($satir);
        $this->assertEqualsWithDelta(36.8841, (float) $satir->lat, 0.000001);
        $this->assertEqualsWithDelta(8.0, (float) $satir->accuracy_m, 0.000001);
    }

    #[Test]
    public function kalp_atisini_her_rol_gonderebilir(): void
    {
        // Patron da sahadadır, operatör de dükkândadır — gönderme yetkisi role bağlanmaz.
        $a = $this->makeTenant('a');
        $govde = ['lat' => self::KEPEZ[0], 'lng' => self::KEPEZ[1]];

        foreach ([$a['patron'], $a['operator'], $a['kurye']] as $kullanici) {
            $this->asToken($this->tokenFor($kullanici))
                ->postJson('/api/v1/locations/heartbeat', $govde)
                ->assertNoContent();
        }

        $this->assertSame(3, $this->satirSayisi(), 'Üç kullanıcı → üç satır (kullanıcı başına bir).');
    }

    #[Test]
    public function gecersiz_enlem_422_verir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['kurye']);

        $this->asToken($token)->postJson('/api/v1/locations/heartbeat', [
            'lat' => 91, 'lng' => 29.0,
        ])->assertStatus(422)->assertJsonValidationErrors('lat');

        $this->assertSame(0, $this->satirSayisi(), 'Reddedilen istek satır yazmamalı.');
    }

    #[Test]
    public function gecersiz_boylam_ve_negatif_dogruluk_422_verir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['kurye']);

        $this->asToken($token)->postJson('/api/v1/locations/heartbeat', [
            'lat' => 36.9, 'lng' => 181,
        ])->assertStatus(422)->assertJsonValidationErrors('lng');

        $this->asToken($token)->postJson('/api/v1/locations/heartbeat', [
            'lat' => 36.9, 'lng' => 30.6, 'accuracy_m' => -1,
        ])->assertStatus(422)->assertJsonValidationErrors('accuracy_m');
    }

    #[Test]
    public function canli_listeyi_kurye_okuyamaz(): void
    {
        $a = $this->makeTenant('a');

        $this->asToken($this->tokenFor($a['kurye']))
            ->getJson('/api/v1/locations/live')->assertForbidden();

        // Operatör de patron değildir — 403 yalnız kuryeye özgü bir kural değil.
        $this->asToken($this->tokenFor($a['operator']))
            ->getJson('/api/v1/locations/live')->assertForbidden();
    }

    #[Test]
    public function patron_canli_listeyi_sozlesme_alanlariyla_okur(): void
    {
        $a = $this->makeTenant('a');
        $kuryeToken = $this->tokenFor($a['kurye']);

        $this->asToken($kuryeToken)->postJson('/api/v1/locations/heartbeat', [
            'lat' => self::KEPEZ[0], 'lng' => self::KEPEZ[1], 'accuracy_m' => 12.5,
        ])->assertNoContent();

        $yanit = $this->asToken($this->tokenFor($a['patron']))->getJson('/api/v1/locations/live');

        $yanit->assertOk();
        $yanit->assertJsonCount(1, 'locations');

        /** @var array<string, mixed> $satir */
        $satir = $yanit->json('locations.0');

        // Alan KÜMESİ birebir: eksik alan istemciyi kırar, fazla alan sessizce veri sızdırır.
        $this->assertSame(
            ['user_id', 'name', 'role', 'lat', 'lng', 'accuracy_m', 'reported_at', 'is_fresh'],
            array_keys($satir),
        );

        $this->assertSame($a['kurye']->id, $satir['user_id']);
        $this->assertSame($a['kurye']->name, $satir['name']);
        $this->assertSame('kurye', $satir['role']);
        $this->assertEqualsWithDelta(self::KEPEZ[0], $satir['lat'], 0.000001);
        $this->assertEqualsWithDelta(self::KEPEZ[1], $satir['lng'], 0.000001);
        $this->assertEqualsWithDelta(12.5, $satir['accuracy_m'], 0.000001);
        $this->assertTrue($satir['is_fresh'], 'Yeni gönderilen kalp atışı TAZE olmalı.');
        $this->assertIsString($satir['reported_at']);
        $this->assertNotNull(CarbonImmutable::parse($satir['reported_at']));
    }

    #[Test]
    public function yanitta_telefon_ve_eposta_bulunmaz(): void
    {
        // KVKK kırmızı çizgi #4: ad ve rol yeter; iletişim bilgisi koordinatla aynı yanıtta olmaz.
        $a = $this->makeTenant('a');
        $this->asOwner(fn () => User::query()->whereKey($a['kurye']->id)->update(['phone' => '05321234567']));

        $this->asToken($this->tokenFor($a['kurye']))->postJson('/api/v1/locations/heartbeat', [
            'lat' => self::KEPEZ[0], 'lng' => self::KEPEZ[1],
        ])->assertNoContent();

        $yanit = $this->asToken($this->tokenFor($a['patron']))->getJson('/api/v1/locations/live');

        $yanit->assertOk();
        $govde = $yanit->getContent();
        $this->assertIsString($govde);
        $this->assertStringNotContainsString('05321234567', $govde);
        $this->assertStringNotContainsString($a['kurye']->email, $govde);
    }

    #[Test]
    public function dort_dakika_onceki_kayit_listede_ama_taze_degil(): void
    {
        $a = $this->makeTenant('a');
        $this->konumYaz($a['kurye'], CarbonImmutable::now()->subMinutes(4));

        $yanit = $this->asToken($this->tokenFor($a['patron']))->getJson('/api/v1/locations/live');

        $yanit->assertOk();
        $yanit->assertJsonCount(1, 'locations');
        // Satır KAYBOLMAZ: kaybolması "kurye yok" demek olurdu; bayat olması "şu an bilmiyoruz".
        $this->assertFalse($yanit->json('locations.0.is_fresh'));
        $this->assertSame($a['kurye']->id, $yanit->json('locations.0.user_id'));
    }

    #[Test]
    public function altmis_bir_dakika_onceki_kayit_listeye_hic_girmez(): void
    {
        $a = $this->makeTenant('a');
        $this->konumYaz($a['kurye'], CarbonImmutable::now()->subMinutes(61));

        $yanit = $this->asToken($this->tokenFor($a['patron']))->getJson('/api/v1/locations/live');

        $yanit->assertOk();
        $yanit->assertJsonCount(0, 'locations');
        // Satır DB'de duruyor (bir sonraki kalp atışında ezilecek) ama YANITA girmiyor —
        // pencere bir gizlilik sınırıdır, temizlik işi değil.
        $this->assertSame(1, $this->satirSayisi());
        $govde = $yanit->getContent();
        $this->assertIsString($govde);
        $this->assertStringNotContainsString($a['kurye']->id, $govde);
    }

    #[Test]
    public function esikler_config_ile_belirlenir(): void
    {
        // Tazelik kuralı SUNUCUDA ve tek yerde: eşiği değiştirmek yanıtı değiştirmeli, yoksa
        // sabit bir yere kaçmış demektir.
        $a = $this->makeTenant('a');
        $this->konumYaz($a['kurye'], CarbonImmutable::now()->subMinutes(4));

        config()->set('konum.taze_dakika', 10);
        $yanit = $this->asToken($this->tokenFor($a['patron']))->getJson('/api/v1/locations/live');
        $this->assertTrue($yanit->json('locations.0.is_fresh'), '10 dk eşiğinde 4 dk taze sayılmalı.');

        config()->set('konum.liste_dakika', 2);
        $yanit = $this->asToken($this->tokenFor($a['patron']))->getJson('/api/v1/locations/live');
        $yanit->assertJsonCount(0, 'locations');
    }

    #[Test]
    public function kalp_atisi_kendi_hiz_sinirina_tabidir(): void
    {
        // `throttle:konum` gerçekten bağlı mı: genel api sınırı (60/dk) devreye girmeden ÖNCE
        // 429 gelmeli, yoksa bozuk bir istemci döngüsü kullanıcının gerçek isteklerini yerdi.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['kurye']);
        $govde = ['lat' => self::KEPEZ[0], 'lng' => self::KEPEZ[1]];

        for ($i = 0; $i < 6; $i++) {
            $this->asToken($token)->postJson('/api/v1/locations/heartbeat', $govde)->assertNoContent();
        }

        $this->asToken($token)->postJson('/api/v1/locations/heartbeat', $govde)->assertStatus(429);
    }

    #[Test]
    public function tokensiz_konum_uclari_401_verir(): void
    {
        $this->postJson('/api/v1/locations/heartbeat', ['lat' => 36.9, 'lng' => 30.6])
            ->assertUnauthorized();
        $this->getJson('/api/v1/locations/live')->assertUnauthorized();
    }
}
