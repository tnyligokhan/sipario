<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\OrderLine;
use App\Models\Product;
use App\Support\Provisioning;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * ÜRÜN SEÇENEKLERİ — sunucu sözleşmesi (kullanıcı isteği 2026-08-18: "müşteri içinde şu olsun
 * olmasın diyebilir; işletmede her seferinde bunu sormak istemeyebilir").
 *
 * Üç alan, üç ayrı desen ve üç ayrı tehlike:
 *  - `products.options` ürünün bir ALANIdır ve LWW ile ÜZERİNE YAZILIR.
 *  - `order_lines.options` satırla birlikte DOĞAR (append) — güncellenmez.
 *  - `customers.product_options` müşterinin bir ALANIdır; ASIL TEHLİKE burada ve `FavoriVeSatirNotu`
 *    testinin kilitlediği kuralın aynısı: alanı bilmeyen sahadaki eski bir build müşterinin adını
 *    düzelttiğinde tercihleri SİLMEMELİ.
 *
 * Dördüncü iddia hepsi için ortak: SUNUCUDA DOĞRU DURAN AMA İNMEYEN ALAN YOKTUR — yeni alanlar
 * delta yolundan telefona GERÇEK JSON olarak ulaşmalı, metin olarak değil.
 */
class UrunSecenekleriTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /** @return array<string, mixed> */
    private function secenekler(): array
    {
        return [
            ['ad' => 'Soğan', 'varsayilan' => true],
            ['ad' => 'Ekstra peynir', 'varsayilan' => false, 'ekKurus' => 1000],
        ];
    }

    #[Test]
    public function urunun_secenek_listesi_yazilir_ve_delta_ile_iner(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $urunId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $this->event('product', 'upsert', [
                'id' => $urunId,
                'name' => 'Tavuk Dürüm',
                'unit_price_kurus' => 10000,
                'options' => $this->secenekler(),
            ]),
        ])->assertJsonPath('results.0.status', 'applied');

        $urun = Provisioning::asOwner(fn () => Product::query()->find($urunId));
        $this->assertNotNull($urun);
        $this->assertSame('Soğan', $urun->options[0]['ad']);
        $this->assertFalse($urun->options[1]['varsayilan']);
        $this->assertSame(1000, $urun->options[1]['ekKurus']);

        // İNMEYEN ALAN = O TELEFONDA HİÇ OLMAYAN ALAN (migration 802'nin dersi). Alan HER İKİ
        // yoldan da inmeli ve GERÇEK JSON olarak: metin olarak inseydi mobil ayrıştırıcı iki
        // biçim beklemek zorunda kalırdı.
        $snapshot = $this->pullSince($token, 0);
        $snapshot->assertJsonPath('mode', 'snapshot');
        $snapUrun = collect($snapshot->json('entities.product'))->firstWhere('id', $urunId);
        $this->assertIsArray($snapUrun['options'] ?? null, 'Seçenekler snapshot yolundan inmiyor.');
        $this->assertSame('Soğan', $snapUrun['options'][0]['ad']);

        // DELTA: snapshot'tan SONRA yazılan ürün delta yolundan inmeli.
        $imlec = (int) $snapshot->json('cursor');
        $ikinciId = (string) Str::uuid7();
        $this->pushEvents($token, [
            $this->event('product', 'upsert', [
                'id' => $ikinciId,
                'name' => 'Et Dürüm',
                'unit_price_kurus' => 12000,
                'options' => $this->secenekler(),
            ]),
        ])->assertJsonPath('results.0.status', 'applied');

        $delta = $this->pullSince($token, $imlec);
        $delta->assertJsonPath('mode', 'delta');
        $degisim = collect($delta->json('changes'))
            ->firstWhere(fn (array $c) => $c['entity_type'] === 'product' && $c['entity_id'] === $ikinciId);
        $this->assertNotNull($degisim, 'Ürün delta yolunda hiç görünmüyor.');
        $this->assertIsArray($degisim['payload']['options'] ?? null);
        $this->assertSame('Soğan', $degisim['payload']['options'][0]['ad']);
    }

    #[Test]
    public function satirin_secimi_satirla_birlikte_dogar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $satirId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $this->orderCreated([
                $this->line([
                    'id' => $satirId,
                    'product_name' => 'Tavuk Dürüm',
                    // Ekstra birim fiyata İSTEMCİDE binmiş hâlde gelir; sunucu yeniden hesaplamaz
                    // (aynı formülün ikinci kopyası bir gün ayrışırdı).
                    'unit_price_kurus' => 11000,
                    'qty' => 1,
                    'note' => 'Soğan olmasın · + Ekstra peynir',
                    'options' => [
                        'cikarilan' => ['Soğan'],
                        'eklenen' => [
                            ['ad' => 'Ekstra peynir', 'varsayilan' => false, 'ekKurus' => 1000],
                        ],
                    ],
                ]),
            ]),
        ])->assertJsonPath('results.0.status', 'applied');

        $satir = Provisioning::asOwner(fn () => OrderLine::query()->find($satirId));
        $this->assertNotNull($satir);
        $this->assertSame(['Soğan'], $satir->options['cikarilan']);
        $this->assertSame(1000, $satir->options['eklenen'][0]['ekKurus']);
        // METİN DE YAZILMALI: ekranların tamamı `note` alanını çiziyor.
        $this->assertSame('Soğan olmasın · + Ekstra peynir', $satir->note);
        $this->assertSame(11000, $satir->line_total_kurus);
    }

    #[Test]
    public function musteri_tercihi_ad_duzeltmesinde_korunur(): void
    {
        // ⚠️ BU DOSYANIN EN KRİTİK TESTİ. Sunucu `customer` upsert'ini TAM SATIR olarak uygular;
        // anahtar payload'da HİÇ YOKSA mevcut değer korunmalı. Korunmazsa, alanı bilmeyen bir
        // build (ya da panelin müşteri formu) bir ad düzeltmesiyle bütün tercihleri siler ve
        // bunu kimse görmez.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $musteriId = (string) Str::uuid7();
        $urunId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $this->customerUpsert([
                'id' => $musteriId,
                'name' => 'Ayşe',
                'product_options' => [
                    $urunId => ['cikarilan' => ['Soğan']],
                ],
            ]),
        ])->assertJsonPath('results.0.status', 'applied');

        // Alanı HİÇ göndermeyen bir ad düzeltmesi.
        $this->pushEvents($token, [
            $this->customerUpsert(
                ['id' => $musteriId, 'name' => 'Ayşe Yılmaz'],
                ['occurred_at' => now()->addMinute()->toIso8601String()]
            ),
        ])->assertJsonPath('results.0.status', 'applied');

        $musteri = Provisioning::asOwner(fn () => Customer::query()->find($musteriId));
        $this->assertSame('Ayşe Yılmaz', $musteri->name);
        $this->assertSame(
            ['Soğan'],
            $musteri->product_options[$urunId]['cikarilan'] ?? null,
            'Ad düzeltmesi müşterinin ürün tercihlerini silmemeli.'
        );
    }

    #[Test]
    public function acikca_null_gonderilirse_tercih_temizlenir(): void
    {
        // "Anahtar YOK" ile "anahtar null" AYRI şeylerdir: ilki korur, ikincisi temizler.
        // Bu ayrım olmasaydı kullanıcının tercihini SİLMESİ ifade edilemez olurdu.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $musteriId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $this->customerUpsert([
                'id' => $musteriId,
                'name' => 'Ayşe',
                'product_options' => [(string) Str::uuid7() => ['cikarilan' => ['Soğan']]],
            ]),
        ])->assertJsonPath('results.0.status', 'applied');

        $this->pushEvents($token, [
            $this->customerUpsert(
                ['id' => $musteriId, 'name' => 'Ayşe', 'product_options' => null],
                ['occurred_at' => now()->addMinute()->toIso8601String()]
            ),
        ])->assertJsonPath('results.0.status', 'applied');

        $musteri = Provisioning::asOwner(fn () => Customer::query()->find($musteriId));
        $this->assertNull($musteri->product_options);
    }

    #[Test]
    public function negatif_ek_ucret_reddedilir(): void
    {
        // Negatif bir ek tutar satırın birim fiyatını düşürür — denetlenmeyen ikinci bir indirim
        // kanalı. İskontonun kendi kaydı, kendi yetkisi ve gün sonunda kendi satırı var.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [
            $this->event('product', 'upsert', [
                'id' => (string) Str::uuid7(),
                'name' => 'Dürüm',
                'unit_price_kurus' => 10000,
                'options' => [['ad' => 'İndirim', 'varsayilan' => false, 'ekKurus' => -5000]],
            ]),
        ])->assertOk()->assertJsonPath('results.0.status', 'rejected');
    }

    #[Test]
    public function bozuk_bicimler_reddedilir(): void
    {
        // Gevşek davranmanın bedeli ağır: alan `json` kolonda bütün olarak durur ve istemci onu
        // SORGUSUZ okur. Bugün kabul edilen her sapkın biçim, yarın telefonda sessizce boşa
        // düşen bir liste demektir — bayi kaydettiğini sanar, liste hiç görünmez.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $bozuklar = [
            'metin olarak JSON' => '[{"ad":"Soğan"}]',
            'nesne (dizi değil)' => ['ad' => 'Soğan'],
            'adsız seçenek' => [['varsayilan' => true]],
            'boş ad' => [['ad' => '   ']],
            'sayısal ad' => [['ad' => 5]],
            'metin ekKurus' => [['ad' => 'Peynir', 'ekKurus' => '1000']],
        ];

        foreach ($bozuklar as $etiket => $ham) {
            $this->pushEvents($token, [
                $this->event('product', 'upsert', [
                    'id' => (string) Str::uuid7(),
                    'name' => 'Dürüm',
                    'unit_price_kurus' => 10000,
                    'options' => $ham,
                ]),
            ])->assertOk()->assertJsonPath('results.0.status', 'rejected', "biçim kabul edildi: {$etiket}");
        }
    }

    #[Test]
    public function ayni_ad_iki_kez_duramaz(): void
    {
        // Seçim `ad` üzerinden eşleşiyor (satır "Soğan çıkarıldı" der, indeks numarası değil);
        // tekrar eden ad hangi satırın kastedildiğini belirsiz kılardı. İlk görülen kazanır.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $urunId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $this->event('product', 'upsert', [
                'id' => $urunId,
                'name' => 'Dürüm',
                'unit_price_kurus' => 10000,
                'options' => [
                    ['ad' => 'Soğan', 'varsayilan' => true],
                    ['ad' => 'soğan', 'varsayilan' => false],
                ],
            ]),
        ])->assertJsonPath('results.0.status', 'applied');

        $urun = Provisioning::asOwner(fn () => Product::query()->find($urunId));
        $this->assertCount(1, $urun->options);
        $this->assertTrue($urun->options[0]['varsayilan'], 'ilk görülen kazanır');
    }
}
