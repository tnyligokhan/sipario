<?php

namespace Tests\Feature\Api;

use App\Support\Route\RotaMotoru;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsRouteStops;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * "Oto Sırala (rota)" MOTOR seçimi — Google Routes sürücüsü ve onun düşme (fallback) davranışı.
 *
 * Bu dosyanın asıl sınadığı şey sıra değil DAYANIKLILIK: paralı dış servis her şekilde
 * arızalanabilir (anahtar yok, faturalandırma kapalı, 500, kapasite aşımı) ve hiçbirinde
 * kullanıcı 5xx görmemeli, kontörü iki kez yanmamalı, yanıtına sağlayıcı ayrıntısı sızmamalı.
 *
 * Sıranın kendisi ve kontör kuralları `AutoRouteTest`te sabitlenir.
 */
class RotaMotoruTest extends ApiTestCase
{
    use BuildsRouteStops;
    use BuildsSyncEvents;

    private const KEPEZ = [36.9125, 30.6689];

    private const MURATPASA = [36.8841, 30.7056];

    private const LARA = [36.8632, 30.7809];

    /** Cihaz konumu (testlerde başlangıç): buradan kuş uçuşu en uzak durak LARA'dır. */
    private const MERKEZ = ['lat' => 36.8969, 'lng' => 30.7133];

    #[Test]
    public function google_surucusu_donen_optimal_sirayi_uygular(): void
    {
        // AYIRT EDİCİ KURGU: start=MERKEZ verilir; en uzak durak LARA hedeftir ve SONA sabitlenir,
        // ara duraklar [kepez, muratpasa]. Google'ın (sahte) cevabı [0, 1] → kepez, muratpaşa, lara.
        //   yakın komşu aynı girdide → muratpaşa, kepez, lara (merkeze en yakın muratpaşa'dır)
        // Yani sonuç NN'den farklıdır; sıra gerçekten Google'dan geliyor demektir.
        Http::fake(['routes.googleapis.com/*' => Http::response([
            'routes' => [['optimizedIntermediateWaypointIndex' => [0, 1]]],
        ])]);

        [$token, $tenantId, $siparisler] = $this->uckDurakKur(6);
        $this->googleSurucusunuAc();

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$siparisler['lara'], $siparisler['kepez'], $siparisler['muratpasa']],
            'start' => self::MERKEZ,
        ]);

        $yanit->assertOk();
        $this->assertSame(
            [$siparisler['kepez'], $siparisler['muratpasa'], $siparisler['lara']],
            $yanit->json('order'),
            'ara duraklar Google sırasında, EN UZAK durak (lara) hedef olarak sonda',
        );
        $this->assertSame(RotaMotoru::GOOGLE, $yanit->json('engine'));
        $this->assertSame(5, $yanit->json('route_credits'), 'bir hak düşer');
        $this->assertSame(5, $this->routeCredits($tenantId));
        Http::assertSentCount(1);
    }

    #[Test]
    public function google_reddederse_yakin_komsuya_dusulur_ve_kontor_yine_bir_yanar(): void
    {
        // Faturalandırma kapalıyken Google'ın gerçek cevabı budur: 403 + PERMISSION_DENIED.
        // Kullanıcı bunu GÖRMEZ; sıra biraz kabalaşır, o kadar.
        Http::fake(['routes.googleapis.com/*' => Http::response([
            'error' => [
                'code' => 403,
                'status' => 'PERMISSION_DENIED',
                'message' => 'Routes API has not been used in project 123 before or it is disabled. Enable Billing.',
            ],
        ], 403)]);

        [$token, $tenantId, $siparisler] = $this->uckDurakKur(4);
        $this->googleSurucusunuAc();

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$siparisler['lara'], $siparisler['kepez'], $siparisler['muratpasa']],
            'start' => self::MERKEZ,
        ]);

        $yanit->assertOk();
        $this->assertSame(RotaMotoru::YAKIN_KOMSU, $yanit->json('engine'));
        $this->assertSame(
            [$siparisler['muratpasa'], $siparisler['kepez'], $siparisler['lara']],
            $yanit->json('order'),
            'düşünce yakın komşu zinciri devralır (merkezden: muratpaşa → kepez → lara)',
        );

        // Kontör MOTOR FARK ETMEKSİZİN 1 düşer — Google'a gidip dönmüş olmak ikinci kez yakmaz.
        $this->assertSame(3, $yanit->json('route_credits'));
        $this->assertSame(3, $this->routeCredits($tenantId));

        // Sağlayıcı ayrıntısı SIZMAZ: "Billing"/"API key" gibi bir kelime yanıta geçerse
        // hem teşhis gürültüsü olur hem de altyapımız hakkında bilgi verir.
        $ham = (string) $yanit->getContent();
        foreach (['Billing', 'API key', 'PERMISSION_DENIED', 'project'] as $yasak) {
            $this->assertStringNotContainsString($yasak, $ham);
        }
    }

    #[Test]
    public function google_500_verirse_de_yakin_komsuya_dusulur(): void
    {
        // Sunucu tarafı arıza (5xx) da düşme sebebidir; özellik ASLA 5xx'e dönüşmez.
        Http::fake(['routes.googleapis.com/*' => Http::response('bozuk', 500)]);

        [$token, , $siparisler] = $this->uckDurakKur(2);
        $this->googleSurucusunuAc();

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$siparisler['lara'], $siparisler['kepez'], $siparisler['muratpasa']],
            'start' => self::MERKEZ,
        ]);

        $yanit->assertOk();
        $this->assertSame(RotaMotoru::YAKIN_KOMSU, $yanit->json('engine'));
        $this->assertSame(1, $yanit->json('route_credits'));
    }

    #[Test]
    public function anahtar_yokken_googlea_hic_istek_gitmez(): void
    {
        // `ROTA_SURUCU=google` yazılmış ama anahtar boş bırakılmış kurulum. Bağlama bunu
        // ÇAĞRIDAN ÖNCE görür: hiç istek çıkmaz, doğrudan yakın komşu bağlanır.
        Http::fake();

        [$token, , $siparisler] = $this->uckDurakKur(3);
        $this->googleSurucusunuAc(anahtar: '');

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$siparisler['lara'], $siparisler['kepez'], $siparisler['muratpasa']],
        ]);

        $yanit->assertOk();
        $this->assertSame(RotaMotoru::YAKIN_KOMSU, $yanit->json('engine'));
        Http::assertNothingSent();
    }

    #[Test]
    public function ara_durak_tavani_asilinca_googlea_istek_gitmez(): void
    {
        // 29 durak → origin (ilk durak) + hedef (en uzak) düşünce 27 ara durak kalır; Google'ın
        // `optimizeWaypointOrder` tavanı 25'tir. İstek gitseydi 400 ile geri dönerdi: parayı ve
        // saniyeyi boşuna yakmak yerine burada durup yakın komşuya düşeriz. Kullanıcı yine sıra alır.
        Http::fake();

        $a = $this->makeTenant('a');
        $this->setRouteCredits($a['tenant']->id, 5);
        $token = $this->tokenFor($a['patron']);

        $noktalar = [];
        for ($i = 0; $i < 29; $i++) {
            $noktalar['d'.$i] = [36.85 + $i * 0.002, 30.70 + $i * 0.002];
        }
        $siparisler = $this->siparisleriKur($token, $noktalar);

        $this->googleSurucusunuAc();

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => array_values($siparisler),
        ]);

        $yanit->assertOk();
        $this->assertSame(RotaMotoru::YAKIN_KOMSU, $yanit->json('engine'));
        $this->assertCount(29, (array) $yanit->json('order'), 'hiçbir durak kaybolmaz');
        // Noktalar tek bir hat üzerinde artan sırada; yakın komşu gönderilen sırayı korur.
        $this->assertSame(array_values($siparisler), $yanit->json('order'));
        Http::assertNothingSent();
    }

    #[Test]
    public function googlea_giden_govdede_yalnizca_koordinat_vardir(): void
    {
        // KVKK (kırmızı çizgi #4): dışarıya çıkan tek veri KOORDİNATTIR. Müşteri adı, adres
        // metni, telefon — hatta SİPARİŞ KİMLİĞİ bile gövdeye girmez. Sırayı dizin numarasıyla
        // geri alıp kimliği bu uçta eşleriz.
        Http::fake(['routes.googleapis.com/*' => Http::response([
            'routes' => [['optimizedIntermediateWaypointIndex' => [1, 0]]],
        ])]);

        [$token, , $siparisler] = $this->uckDurakKur(5);
        $this->googleSurucusunuAc();

        $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$siparisler['lara'], $siparisler['kepez'], $siparisler['muratpasa']],
            'start' => ['lat' => 36.9200, 'lng' => 30.6600],
        ])->assertOk();

        Http::assertSent(function (Request $istek) use ($siparisler) {
            /** @var array<string, mixed> $govde */
            $govde = $istek->data();

            $this->assertSame(
                ['origin', 'destination', 'intermediates', 'travelMode', 'optimizeWaypointOrder'],
                array_keys($govde),
                'gövdede beklenmedik bir alan yok',
            );

            $ham = (string) json_encode($govde, JSON_UNESCAPED_UNICODE);
            foreach (array_values($siparisler) as $id) {
                $this->assertStringNotContainsString($id, $ham, 'sipariş kimliği dışarı çıkmaz');
            }
            foreach (['Müşteri', 'Mah.', 'phone', 'customer', 'name'] as $yasak) {
                $this->assertStringNotContainsString($yasak, $ham);
            }

            // Başlangıç cihaz konumu; varış EN UZAK duraktır (lara) — gidiş-dönüş DEĞİL
            // (döngü yönü belirsizliği sahada "en uzak 1. sırada" arızası üretmişti).
            $this->assertSame(
                ['location' => ['latLng' => ['latitude' => 36.92, 'longitude' => 30.66]]],
                $govde['origin'],
            );
            $this->assertSame(
                ['location' => ['latLng' => ['latitude' => self::LARA[0], 'longitude' => self::LARA[1]]]],
                $govde['destination'],
                'hedef = başlangıca kuş uçuşu en uzak durak',
            );
            $this->assertNotSame($govde['origin'], $govde['destination']);
            $this->assertCount(2, (array) $govde['intermediates'], 'en uzak durak hedefe ayrıldı, 2 ara kaldı');

            return true;
        });
    }

    // ── yardımcılar ─────────────────────────────────────────────────────────────────────────

    #[Test]
    public function bozuk_permutasyon_yakin_komsuya_dusurur(): void
    {
        // İnceleme bulgusu (2026-07-29): dizinleriAyristir'ın katı doğrulaması "en pahalı arıza
        // türü" diye işaretlenmişti ama hiçbir test onu TETİKLEMİYORDU. Tekrarlı dizin ([0,0])
        // sessizce durak KAYBETTİRİRDİ: kurye bir müşteriye hiç uğramaz, hiçbir şey hata vermez.
        // Doğru davranış: istisna → yakın komşuya düşüş → TAM permütasyonlu bir sıra.
        Http::fake(['routes.googleapis.com/*' => Http::response([
            'routes' => [['optimizedIntermediateWaypointIndex' => [0, 0]]],
        ])]);

        [$token, $tenantId, $siparisler] = $this->uckDurakKur(6);
        $this->googleSurucusunuAc();

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$siparisler['lara'], $siparisler['kepez'], $siparisler['muratpasa']],
            'start' => self::MERKEZ,
        ]);

        $yanit->assertOk();
        $this->assertSame(RotaMotoru::YAKIN_KOMSU, $yanit->json('engine'));
        // Sıra ne olursa olsun TAM permütasyon: üç sipariş de tam bir kez.
        $sira = $yanit->json('order');
        $this->assertCount(3, $sira);
        $this->assertEqualsCanonicalizing(array_values($siparisler), $sira);
        $this->assertSame(5, $this->routeCredits($tenantId), 'düşüşte de tek kontör yanar');
    }

    #[Test]
    public function ag_arizasi_yakin_komsuya_dusurur(): void
    {
        // Kullanıcının en sık göreceği arıza: ağ yok/kesik. ConnectionException yolu da diğer
        // arızalarla aynı sözleşmeye uymalı — 5xx yok, tek kontör, yakın komşu sırası.
        Http::fake([
            'routes.googleapis.com/*' => fn () => throw new ConnectionException('baglanti koptu'),
        ]);

        [$token, $tenantId, $siparisler] = $this->uckDurakKur(6);
        $this->googleSurucusunuAc();

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$siparisler['lara'], $siparisler['kepez'], $siparisler['muratpasa']],
            'start' => self::MERKEZ,
        ]);

        $yanit->assertOk();
        $this->assertSame(RotaMotoru::YAKIN_KOMSU, $yanit->json('engine'));
        $this->assertSame(5, $this->routeCredits($tenantId));
    }

    #[Test]
    public function rota_ucu_kiraci_basina_dakikalik_sinira_tabidir(): void
    {
        // İnceleme bulgusu (2026-07-29): kontör ön-bakışı kilitsiz, paralı çağrı kilitten önce —
        // eşzamanlı yarış tek kontöre karşılık N ücretli çağrı yakabilir. Maliyet tavanı bu
        // sınırdır (geocode deseni). 5/dk; altıncı istek 429.
        Http::fake(['routes.googleapis.com/*' => Http::response([
            'routes' => [['optimizedIntermediateWaypointIndex' => [0, 1]]],
        ])]);

        [$token, , $siparisler] = $this->uckDurakKur(50);
        $this->googleSurucusunuAc();
        $govde = ['order_ids' => array_values($siparisler)];

        for ($i = 0; $i < 5; $i++) {
            $this->asToken($token)->postJson('/api/v1/orders/auto-route', $govde)->assertOk();
        }

        $this->asToken($token)->postJson('/api/v1/orders/auto-route', $govde)->assertStatus(429);
    }

    #[Test]
    public function ayni_siparis_iki_kez_gonderilirse_422(): void
    {
        // "distinct" kuralı: tekrar eden kimlik durak ÇOĞALTIRDI (RotaMotoru sözleşmesi ihlali)
        // ve Google'a iki özdeş ara durak giderdi. Kapıda reddedilir, kontör YANMAZ.
        [$token, $tenantId, $siparisler] = $this->uckDurakKur(6);

        $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$siparisler['lara'], $siparisler['lara']],
        ])->assertStatus(422);

        $this->assertSame(6, $this->routeCredits($tenantId));
    }

    #[Test]
    public function start_govdesindeki_fazladan_alan_reddedilir(): void
    {
        // KVKK gerekçesiyle konmuş kuralın (array:lat,lng) testi yoktu (inceleme bulgusu).
        // Bu uç noktadan dışarıya koordinat çıkıyor; gövdeye sıkı bakılır: fazladan alan,
        // eksik lng ve aralık dışı lng hepsi 422 ve kontör YANMAZ.
        [$token, $tenantId, $siparisler] = $this->uckDurakKur(6);
        $ids = ['order_ids' => array_values($siparisler)];

        $this->asToken($token)->postJson(
            '/api/v1/orders/auto-route',
            $ids + ['start' => ['lat' => 36.9, 'lng' => 30.7, 'name' => 'Ayşe']]
        )->assertStatus(422);
        $this->asToken($token)->postJson(
            '/api/v1/orders/auto-route',
            $ids + ['start' => ['lat' => 36.9]]
        )->assertStatus(422);
        $this->asToken($token)->postJson(
            '/api/v1/orders/auto-route',
            $ids + ['start' => ['lat' => 36.9, 'lng' => 181]]
        )->assertStatus(422);

        $this->assertSame(6, $this->routeCredits($tenantId));
    }

    /**
     * Bir bayi + üç koordinatlı açık sipariş (lara/kepez/muratpasa) + verilen kontör.
     *
     * @return array{0: string, 1: string, 2: array<string, string>} token, tenant kimliği, siparişler
     */
    private function uckDurakKur(int $kontor): array
    {
        $a = $this->makeTenant('a');
        $this->setRouteCredits($a['tenant']->id, $kontor);
        $token = $this->tokenFor($a['patron']);

        $siparisler = $this->siparisleriKur($token, [
            'lara' => self::LARA,
            'kepez' => self::KEPEZ,
            'muratpasa' => self::MURATPASA,
        ]);

        return [$token, $a['tenant']->id, $siparisler];
    }

    /**
     * Google sürücüsünü BU TEST için açar. `phpunit.xml` sürücüyü bilerek `yakin-komsu`da
     * sabitler (geliştirici .env'indeki gerçek anahtarla dış servise çıkılmasın diye); burada
     * yalnız Http::fake altında ve sahte anahtarla açılır. Çözülmüş singleton unutturulur,
     * yoksa bağlama config değişikliğini görmez.
     */
    private function googleSurucusunuAc(string $anahtar = 'sahte-anahtar'): void
    {
        config([
            'rota.surucu' => RotaMotoru::GOOGLE,
            'rota.google.api_key' => $anahtar,
        ]);

        $this->app->forgetInstance(RotaMotoru::class);
    }
}
