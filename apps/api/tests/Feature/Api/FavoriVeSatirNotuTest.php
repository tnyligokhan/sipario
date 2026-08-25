<?php

namespace Tests\Feature\Api;

use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\Order;
use App\Models\OrderLine;
use App\Panel\PanelWriteService;
use App\Support\Provisioning;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * SEPET SATIRI NOTU + FAVORİ ÜRÜNLER — sunucu sözleşmesi (kullanıcı isteği 2026-08-11).
 *
 * İki yeni alan, iki ayrı desen:
 *  - `order_lines.note` satırla birlikte DOĞAR (append; `line_added`/`created`). Güncellenmez,
 *    dolayısıyla sürüm çarpıklığı kapısının konusu değildir.
 *  - `customers.favorite_product_ids` müşteri satırının bir ALANIdır ve LWW ile ÜZERİNE YAZILIR.
 *    Bu yüzden asıl tehlike burada: alanı bilmeyen sahadaki eski bir build müşterinin adını
 *    düzelttiğinde listeyi silmemeli. O kural bu dosyanın en kritik testidir
 *    (`favori_anahtari_hic_gonderilmezse_mevcut_liste_korunur`) ve SurumCarpikligiTest'in
 *    "anahtar YOK ≠ anahtar null" sözleşmesini bu iki alan için de kilitler.
 *
 * Üçüncü iddia her iki alan için ortak: SUNUCUDA DOĞRU DURAN AMA İNMEYEN ALAN YOKTUR (migration
 * 802'nin dersi) — yeni alanlar hem snapshot hem delta yolundan telefona ulaşmalı ve delta'da
 * favori listesi JSON METNİ değil GERÇEK BİR DİZİ olarak inmeli.
 */
class FavoriVeSatirNotuTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /** Owner ile satır okuma (RLS dışı doğrulama). */
    private function musteriOku(string $id): ?Customer
    {
        return Provisioning::asOwner(fn () => Customer::query()->find($id));
    }

    private function satirOku(string $id): ?OrderLine
    {
        return Provisioning::asOwner(fn () => OrderLine::query()->find($id));
    }

    /** @return list<string> */
    private function urunIdleri(int $adet): array
    {
        return array_map(fn () => (string) Str::uuid7(), range(1, $adet));
    }

    // ==================================================================================
    // A) SEPET SATIRI NOTU — order_lines.note
    // ==================================================================================

    #[Test]
    public function satir_notu_yazilir_ve_geri_okunur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $notlu = (string) Str::uuid7();
        $notsuz = (string) Str::uuid7();
        $siparis = (string) Str::uuid7();

        $this->pushEvents($token, [$this->orderCreated([
            $this->line(['id' => $notlu, 'product_name' => '19L Damacana', 'note' => 'Buzlu olsun']),
            $this->line(['id' => $notsuz, 'product_name' => 'Su Pompası']),
        ], ['id' => $siparis])])->assertJsonPath('results.0.status', 'applied');

        $this->assertSame('Buzlu olsun', $this->satirOku($notlu)?->note);
        // NOT SATIRA AİTTİR, SİPARİŞE DEĞİL: aynı sepetteki diğer satır notsuz kalmalı.
        $this->assertNull($this->satirOku($notsuz)?->note, 'Satır notu bütün sepete bulaştı.');
        // `orders.note` AYRI bir alandır ve satır notundan etkilenmez.
        $this->assertNull(Provisioning::asOwner(fn () => Order::query()->find($siparis))?->note);
    }

    #[Test]
    public function satir_notu_line_added_yolundan_da_yazilir(): void
    {
        // Sepete SONRADAN eklenen satırın da notu olmalı — `created` ve `line_added` aynı
        // `insertLine`dan geçer, ama iki ayrı op olduğu için ikisi de sınanır.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $siparis = (string) Str::uuid7();
        $this->pushEvents($token, [$this->orderCreated([$this->line()], ['id' => $siparis])])
            ->assertJsonPath('results.0.status', 'applied');

        $sonraki = (string) Str::uuid7();
        $this->pushEvents($token, [$this->orderEvent('line_added', [
            'order_id' => $siparis,
            'line' => $this->line(['id' => $sonraki, 'note' => 'Kapıya bırak']),
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->assertSame('Kapıya bırak', $this->satirOku($sonraki)?->note);
    }

    #[Test]
    public function satir_notu_bos_metin_null_olur(): void
    {
        // "not yok" TEK bir hâl olmalı: boş dize ile null iki ayrı değer olsaydı istemcideki
        // "bu satırın notu var mı" kapısı iki dala ayrılırdı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $satir = (string) Str::uuid7();
        $this->pushEvents($token, [$this->orderCreated([$this->line(['id' => $satir, 'note' => '   '])])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->assertNull($this->satirOku($satir)?->note);
    }

    #[Test]
    public function satir_notu_500_sinirinda_kabul_501_de_reddedilir_parti_akar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // Tam sınır KABUL: kapı 500'de kapanmaz, 501'de kapanır.
        $sinirdaki = (string) Str::uuid7();
        $this->pushEvents($token, [$this->orderCreated([
            $this->line(['id' => $sinirdaki, 'note' => str_repeat('a', 500)]),
        ])])->assertJsonPath('results.0.status', 'applied');
        $this->assertSame(500, mb_strlen((string) $this->satirOku($sinirdaki)?->note));

        // 501 REDDEDİLİR — ve PARTİNİN GERİ KALANI YAZILIR (savepoint izolasyonu). Bu, kırmızı
        // çizgi #3'ün şema tarafındaki karşılığıdır: tek bozuk satır bekleyen siparişi düşüremez.
        $oncekiMusteri = (string) Str::uuid7();
        $sonrakiMusteri = (string) Str::uuid7();
        $bozukSiparis = (string) Str::uuid7();

        $yanit = $this->pushEvents($token, [
            $this->customerUpsert(['id' => $oncekiMusteri, 'name' => 'Önceki Müşteri']),
            $this->orderCreated(
                [$this->line(['note' => str_repeat('a', 501)])],
                ['id' => $bozukSiparis],
            ),
            $this->customerUpsert(['id' => $sonrakiMusteri, 'name' => 'Sonraki Müşteri']),
        ]);

        $yanit->assertOk();
        $yanit->assertJsonPath('results.0.status', 'applied');
        $yanit->assertJsonPath('results.1.status', 'rejected');
        $yanit->assertJsonPath('results.1.reason', 'domain_rejected');
        $yanit->assertJsonPath('results.2.status', 'applied');

        $this->assertNotNull($this->musteriOku($oncekiMusteri), 'Reddedilen olaydan ÖNCEKİ yazım kayboldu.');
        $this->assertNotNull($this->musteriOku($sonrakiMusteri), 'Reddedilen olaydan SONRAKİ yazım kayboldu.');
        // Reddedilen olayın YARIM kalan izi de olmamalı: sipariş satırı yazılamadan önce
        // eklenmişti, savepoint onu da geri almalı.
        $this->assertNull(
            Provisioning::asOwner(fn () => Order::query()->find($bozukSiparis)),
            'Reddedilen sipariş yarım yazıldı — savepoint geri almadı.'
        );
    }

    #[Test]
    public function satir_notu_snapshot_ve_delta_yollarindan_iner(): void
    {
        // "Sunucuda doğru duran ama inmeyen alan YOKTUR" (migration 802'nin dersi).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $siparis = (string) Str::uuid7();
        $satir = (string) Str::uuid7();
        $this->pushEvents($token, [$this->orderCreated(
            [$this->line(['id' => $satir, 'note' => 'Buzlu olsun'])],
            ['id' => $siparis],
        )])->assertJsonPath('results.0.status', 'applied');

        $snapshot = $this->pullSince($token, 0);
        $snapshot->assertJsonPath('mode', 'snapshot');
        $snapSatir = collect($snapshot->json('entities.order_line'))->firstWhere('id', $satir);
        $this->assertSame('Buzlu olsun', $snapSatir['note'] ?? null, 'Satır notu snapshot yolundan inmiyor.');

        // Delta imleci: buraya kadarki her şey snapshot'ta indi; bundan SONRAKİ satır deltadan inmeli.
        $imlec = (int) $snapshot->json('cursor');
        $ikinci = (string) Str::uuid7();
        $this->pushEvents($token, [$this->orderEvent('line_added', [
            'order_id' => $siparis,
            'line' => $this->line(['id' => $ikinci, 'note' => 'Ayrı poşete']),
        ])])->assertJsonPath('results.0.status', 'applied');

        $deltaYanit = $this->pullSince($token, $imlec);
        $deltaYanit->assertJsonPath('mode', 'delta');
        $deltaSatir = collect($deltaYanit->json('changes'))
            ->firstWhere(fn (array $c) => $c['entity_type'] === 'order_line' && $c['entity_id'] === $ikinci);
        $this->assertNotNull($deltaSatir, 'Satır delta yolunda hiç görünmüyor.');
        $this->assertSame('Ayrı poşete', $deltaSatir['payload']['note'] ?? null, 'Satır notu delta yolundan inmiyor.');
    }

    // ==================================================================================
    // B) FAVORİ ÜRÜNLER — customers.favorite_product_ids
    // ==================================================================================

    #[Test]
    public function favori_listesi_sirasini_koruyarak_yazilir(): void
    {
        // SIRA BAYİNİN TERCİHİDİR (en sık aldığı ürün başta) — alfabetik sıralamak bilgiyi siler.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // Bilerek alfabetik OLMAYAN bir sıra: yeniden dizilirse test kırmızıya döner.
        [$zeta, $alfa, $beta] = ['z-'.Str::uuid7(), 'a-'.Str::uuid7(), 'b-'.Str::uuid7()];

        $id = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert([
            'id' => $id, 'favorite_product_ids' => [$zeta, $alfa, $beta],
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->assertSame([$zeta, $alfa, $beta], $this->musteriOku($id)?->favorite_product_ids);
    }

    #[Test]
    public function favori_listesinde_tekrarlar_teklenir_ilk_sira_korunur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        [$x, $y] = $this->urunIdleri(2);
        $id = (string) Str::uuid7();

        $this->pushEvents($token, [$this->customerUpsert([
            'id' => $id, 'favorite_product_ids' => [$x, $y, $x, $y, $x],
        ])])->assertJsonPath('results.0.status', 'applied');

        // Tekleme İLK görülen konumu korur — son görülen değil. Yoksa "en sık aldığı ürün başta"
        // sırası, tekrarların gönderiliş sırasına göre sessizce değişirdi.
        $this->assertSame([$x, $y], $this->musteriOku($id)?->favorite_product_ids);
    }

    #[Test]
    public function bos_dizi_null_olur(): void
    {
        // "favorisi yok" TEK bir hâldir: `[]` ile `null` iki ayrı değer olsaydı istemcinin
        // "liste boş mu" kapısı iki dala ayrılır, ikisinden biri er geç unutulurdu.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $id = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert(['id' => $id, 'favorite_product_ids' => []])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->assertNull($this->musteriOku($id)?->favorite_product_ids);
        // Kolonda da NULL durmalı — `'[]'` metni yazılmış olsaydı cast bunu boş dizi olarak
        // okur ve yukarıdaki iddia geçerdi; kolonu ham okuyarak o yanılgıyı kapatıyoruz.
        $this->assertNull(Provisioning::asOwner(
            fn () => Customer::query()->whereKey($id)->value('favorite_product_ids')
        ));
    }

    #[Test]
    public function bozuk_bicimler_reddedilir_parti_akar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $bozuklar = [
            'nesne dizisi' => [['id' => 'urun-1']],
            'ic ice dizi' => [['urun-1', 'urun-2']],
            'sayi elemani' => [42],
            'bool elemani' => [true],
            'null elemani' => [null],
            'anahtarli nesne' => ['ilk' => 'urun-1'],
            'duz sayi' => 42,
            'json metni' => '["urun-1","urun-2"]',
            'bos id' => ['urun-1', '   '],
            'cok uzun id' => [str_repeat('u', 65)],
        ];

        foreach ($bozuklar as $ad => $deger) {
            // Her bozuk olay, SAĞLAM bir olayın YANINDA gönderilir: reddin partiyi düşürmediğini
            // her biçim için ayrı ayrı kanıtlıyoruz (zehirli hap sınıfı).
            $saglam = (string) Str::uuid7();
            $bozuk = (string) Str::uuid7();

            $yanit = $this->pushEvents($token, [
                $this->customerUpsert(['id' => $bozuk, 'favorite_product_ids' => $deger]),
                $this->customerUpsert(['id' => $saglam, 'name' => 'Sağlam '.$ad]),
            ]);

            $yanit->assertOk();
            $yanit->assertJsonPath('results.0.status', 'rejected', "Bozuk biçim kabul edildi: {$ad}");
            $yanit->assertJsonPath('results.1.status', 'applied');
            $this->assertNull($this->musteriOku($bozuk), "Reddedilen olay satır yazdı: {$ad}");
            $this->assertNotNull($this->musteriOku($saglam), "Parti düştü: {$ad}");
        }
    }

    #[Test]
    public function yirmi_urun_kabul_yirmi_bir_reddedilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $yirmi = $this->urunIdleri(20);
        $tam = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert(['id' => $tam, 'favorite_product_ids' => $yirmi])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertCount(20, (array) $this->musteriOku($tam)?->favorite_product_ids);

        // 21 → RED. KIRPMA YOK: sessizce kırpmak bayinin listesinden ürün siler ve bunu ancak
        // sipariş ekranında ürünü bulamayınca fark eder.
        $tasan = (string) Str::uuid7();
        $yanit = $this->pushEvents($token, [
            $this->customerUpsert(['id' => $tasan, 'favorite_product_ids' => $this->urunIdleri(21)]),
        ]);
        $yanit->assertJsonPath('results.0.status', 'rejected');
        $yanit->assertJsonPath('results.0.reason', 'domain_rejected');
        $this->assertNull($this->musteriOku($tasan), '21 elemanlı liste kırpılarak yazıldı.');
    }

    #[Test]
    public function sinir_teklemeden_sonra_olculur(): void
    {
        // ÖNCE TEKLEME, SONRA SAYI SINIRI (bilinçli sıra): tekrar bir İSTEMCİ HATASIDIR, bayinin
        // niyeti değil. 25 gönderip 20'si tekil olan bir listeyi reddetmek, bayiye kendi
        // yapmadığı bir hatanın bedelini ödetirdi — sınırın koruduğu şey EFEKTİF listedir.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $yirmi = $this->urunIdleri(20);
        $tekrarli = array_merge($yirmi, array_slice($yirmi, 0, 5)); // 25 eleman, 20 tekil

        $id = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert(['id' => $id, 'favorite_product_ids' => $tekrarli])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->assertSame($yirmi, $this->musteriOku($id)?->favorite_product_ids);
    }

    #[Test]
    public function var_olmayan_urun_kimligi_reddedilmez(): void
    {
        // BİLİNÇLİ KARAR: ürün silinmiş olabilir ve senkron SIRASI garanti değildir — favori
        // listesi ürünün kendisinden ÖNCE inebilir. Yarım kalmış bir sipariş partisini ölü bir
        // favori id'si yüzünden düşürmek orantısız olurdu; istemci çözemediği id'yi ATLAR.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $hayalet = (string) Str::uuid7();
        $id = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert(['id' => $id, 'favorite_product_ids' => [$hayalet]])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->assertSame([$hayalet], $this->musteriOku($id)?->favorite_product_ids);
    }

    // ----------------------------------------------------------------------------------
    // SÜRÜM ÇARPIKLIĞI — bu dosyanın en kritik iki testi
    // ----------------------------------------------------------------------------------

    #[Test]
    public function favori_anahtari_hic_gonderilmezse_mevcut_liste_korunur(): void
    {
        // SAHADAKİ SENARYO: bayi favorileri yeni telefonundan kurar; ESKİ build'li ikinci telefon
        // (alanı bilmiyor, anahtarı hiç göndermiyor) müşterinin adını düzeltir ve damgası TAZEdir.
        // Kapı olmasaydı LWW satırın tamamını yazar, favori listesi SESSİZCE silinirdi — hata yok,
        // günlük yok, alan boş. Bu depoda tam bu sınıf hata iki kez yaşandı (2026-08-05 kararı).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        [$x, $y] = $this->urunIdleri(2);
        $id = (string) Str::uuid7();

        $this->pushEvents($token, [$this->customerUpsert(
            ['id' => $id, 'name' => 'Ahmet Yılmaz', 'favorite_product_ids' => [$x, $y]],
            ['occurred_at' => now()->subMinute()->toIso8601String()],
        )])->assertJsonPath('results.0.status', 'applied');

        // ESKİ BUILD payload'u: `favorite_product_ids` anahtarı HİÇ YOK.
        $eskiPayload = ['id' => $id, 'name' => 'Ahmet Yılmaz (düzeltildi)', 'note' => null];
        $this->assertArrayNotHasKey('favorite_product_ids', $eskiPayload);

        $this->pushEvents($token, [
            $this->event('customer', 'upsert', $eskiPayload, ['occurred_at' => now()->toIso8601String()]),
        ])->assertJsonPath('results.0.status', 'applied');

        $satir = $this->musteriOku($id);
        $this->assertSame('Ahmet Yılmaz (düzeltildi)', $satir?->name, 'LWW artık çalışmıyor.');
        $this->assertSame([$x, $y], $satir?->favorite_product_ids,
            'Alanı bilmeyen eski build bayinin favori listesini SİLDİ.');
    }

    #[Test]
    public function acikca_null_gonderilince_favori_listesi_temizlenir(): void
    {
        // Korumanın BEDELİ olmamalı: "temizle" niyeti ifade edilebilir kalmalı. Ayrım anahtarın
        // VARLIĞINDA — değerinde değil.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $id = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert(
            ['id' => $id, 'favorite_product_ids' => $this->urunIdleri(3)],
            ['occurred_at' => now()->subMinute()->toIso8601String()],
        )])->assertJsonPath('results.0.status', 'applied');
        $this->assertCount(3, (array) $this->musteriOku($id)?->favorite_product_ids);

        $this->pushEvents($token, [$this->customerUpsert(
            ['id' => $id, 'favorite_product_ids' => null],
            ['occurred_at' => now()->toIso8601String()],
        )])->assertJsonPath('results.0.status', 'applied');

        $this->assertNull($this->musteriOku($id)?->favorite_product_ids, 'Açık null listeyi temizlemedi.');
    }

    #[Test]
    public function panel_musteri_duzenlemesi_favori_listesini_silmez(): void
    {
        // Panelin müşteri formu (PanelWriteService/PanelImportService) `favorite_product_ids`
        // anahtarını HİÇ göndermez — yani sürüm çarpıklığı kapısının koruduğu ÜÇÜNCÜ bir yazma
        // yolu daha var ve o yol bugün ÜRETİMDE. Kapı kalkarsa panelden ad düzeltmek bayinin
        // favori listesini siler (kara liste ve ürün görselinde yaşanan tuzağın aynısı).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $admin = Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Yazan Admin', 'email' => 'favori-admin@sipario.test',
            'password' => 'panel-secret', 'role' => 'superadmin',
        ]));

        [$x, $y] = $this->urunIdleri(2);
        $id = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert(
            ['id' => $id, 'name' => 'Panel Müşterisi', 'favorite_product_ids' => [$x, $y]],
            ['occurred_at' => now()->subMinute()->toIso8601String()],
        )])->assertJsonPath('results.0.status', 'applied');

        $sonuc = (new PanelWriteService('pgsql_panel'))->musteriKaydet($a['tenant']->id, [
            'id' => $id, 'ad' => 'Panel Müşterisi (düzeltildi)',
        ], (string) $admin->id);
        $this->assertSame('applied', $sonuc['durum']);

        $satir = $this->musteriOku($id);
        $this->assertSame('Panel Müşterisi (düzeltildi)', $satir?->name);
        $this->assertSame([$x, $y], $satir?->favorite_product_ids, 'Panel düzenlemesi favori listesini sildi.');
    }

    #[Test]
    public function favori_listesi_snapshot_ve_delta_yollarindan_dizi_olarak_iner(): void
    {
        // "Sunucuda doğru duran ama inmeyen alan YOKTUR" (migration 802'nin dersi) + biçim: alan
        // telefona JSON METNİ olarak inerse istemci onu bir kez daha ayrıştırmak zorunda kalır ve
        // sözleşme ("alan ne ise o") kırılır. assertSame dizi bekler — metin gelirse kırmızı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        [$x, $y] = $this->urunIdleri(2);
        $id = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert([
            'id' => $id, 'name' => 'Favorili Müşteri', 'favorite_product_ids' => [$x, $y],
        ])])->assertJsonPath('results.0.status', 'applied');

        $snapshot = $this->pullSince($token, 0);
        $snapshot->assertJsonPath('mode', 'snapshot');
        $snapMusteri = collect($snapshot->json('entities.customer'))->firstWhere('id', $id);
        $this->assertSame([$x, $y], $snapMusteri['favorite_product_ids'] ?? null,
            'Favori listesi snapshot yolundan dizi olarak inmiyor.');

        // Delta imleci: snapshot'tan SONRA yazılan müşteri delta yolundan inmeli.
        $imlec = (int) $snapshot->json('cursor');
        $ikinci = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert([
            'id' => $ikinci, 'name' => 'İkinci Favorili', 'favorite_product_ids' => [$y, $x],
        ])])->assertJsonPath('results.0.status', 'applied');

        $delta = $this->pullSince($token, $imlec);
        $delta->assertJsonPath('mode', 'delta');
        $deltaMusteri = collect($delta->json('changes'))
            ->firstWhere(fn (array $c) => $c['entity_type'] === 'customer' && $c['entity_id'] === $ikinci);
        $this->assertNotNull($deltaMusteri, 'Müşteri delta yolunda hiç görünmüyor.');
        // Sıra deltada da KORUNMALI: [$y, $x] gönderildi, [$y, $x] inmeli.
        $this->assertSame([$y, $x], $deltaMusteri['payload']['favorite_product_ids'] ?? null,
            'Favori listesi delta yolundan dizi olarak inmiyor.');
    }
}
