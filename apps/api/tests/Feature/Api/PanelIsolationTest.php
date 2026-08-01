<?php

namespace Tests\Feature\Api;

use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\Tenant;
use App\Models\User;
use App\Panel\PanelCsvExportService;
use App\Panel\PanelTenantDataService;
use App\Support\Provisioning;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-3 — KIRMIZI ÇİZGİ #1'in panel tarafı: bayi A'nın ekranında bayi B'nin tek bir satırı bile
 * görünmemeli.
 *
 * Panel `sipario_panel` rolüyle okur ve o rol BYPASSRLS'tir: veritabanı burada HİÇBİR koruma
 * sağlamaz. Sızıntıyı yalnız servislerdeki açık `tenant_id` filtreleri önler — yani bu dosya
 * kodun tek savunma hattını sınar.
 *
 * TASARIM KARARI — İKİ BAYİYE BİREBİR AYNI VERİ: her iki bayide de müşterinin adı, TELEFONU ve
 * ürünün adı aynıdır. Farklı değerler kullansaydık eksik bir filtre testten kaçabilirdi (liste
 * "Ahmet" arıyor, B'de "Mehmet" var, sızıntı görünmez). Aynı değerlerle tek ayırt edici şey
 * `tenant_id` olur; doğrulama da isimlere değil KAYIT SAYISINA ve KİMLİKLERE bakar.
 */
class PanelIsolationTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /** İki bayide de aynı — filtre yoksa ayırt edilemezler. */
    private const ORTAK_AD = 'Ortak Müşteri';

    private const ORTAK_TELEFON = '+905321112233';

    private const ORTAK_URUN = 'Ortak Ürün';

    private function data(): PanelTenantDataService
    {
        return new PanelTenantDataService('pgsql_panel');
    }

    private function csv(): PanelCsvExportService
    {
        return new PanelCsvExportService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'İzolasyon', 'email' => 'izo@sipario.test', 'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /**
     * Bir bayiye tam takım veri tohumlar: müşteri (+telefon +adres), ürün, sipariş.
     * Değerler iki bayide AYNIdır; dönen kimlikler farklıdır ve doğrulama onlara bakar.
     *
     * TEK İSTİSNA sipariş NOTUdur: `$etiket` ile bayiye özgü yazılır. Sebebi izolasyon değil
     * ÖLÇÜM — CSV dosyasında satırlar kimlik taşımaz ve sipariş KODU bayi başına sıralıdır (iki
     * bayinin ilk siparişi de 100'dür), yani kodla "bu satır kimin" sorusu cevaplanamaz. Not,
     * dosyada aranabilecek tek ayırt edici alandır. İzolasyon filtrelerinin anahtarladığı alanlar
     * (ad, telefon, ürün adı, barkod) AYNI kalır.
     *
     * @param  array{tenant: Tenant, patron: User}  $seed
     * @return array{musteri: string, urun: string, siparis: string, kod: int}
     */
    private function tohumla(array $seed, string $etiket = 'x'): array
    {
        $token = $this->tokenFor($seed['patron']);

        $musteri = $this->customerUpsert(['name' => self::ORTAK_AD]);
        $mid = $musteri['payload']['id'];
        $urun = $this->event('product', 'upsert', [
            'id' => (string) Str::uuid7(), 'name' => self::ORTAK_URUN, 'unit_price_kurus' => 4500, 'barcode' => '8690000000001',
        ]);
        $uid = $urun['payload']['id'];
        $this->pushEvents($token, [$musteri, $urun])->assertOk();

        $this->pushEvents($token, [
            $this->event('customer_phone', 'upsert', [
                'id' => (string) Str::uuid7(), 'customer_id' => $mid,
                'phone_e164' => self::ORTAK_TELEFON, 'phone_last10' => '5321112233', 'is_primary' => true,
            ]),
            $this->event('customer_address', 'upsert', [
                'id' => (string) Str::uuid7(), 'customer_id' => $mid,
                'address_text' => 'Ortak Adres', 'region' => 'Muratpaşa', 'is_primary' => true,
            ]),
        ])->assertOk();

        $siparis = $this->orderCreated([$this->line(['product_id' => $uid])], ['customer_id' => $mid, 'note' => 'notu-'.$etiket]);
        $sid = $siparis['payload']['order']['id'];
        $this->pushEvents($token, [$siparis])->assertOk();
        $this->pushEvents($token, [$this->ledgerEntry(['customer_id' => $mid, 'entry_type' => 'debit', 'amount_kurus' => 9000, 'related_order_id' => $sid])])->assertOk();

        $kod = (int) $this->asOwner(fn () => Customer::query()->withoutGlobalScopes()->where('id', $mid)->value('code'));

        return ['musteri' => $mid, 'urun' => $uid, 'siparis' => $sid, 'kod' => $kod];
    }

    #[Test]
    public function siparis_listesi_baska_bayinin_siparisini_getirmez(): void
    {
        // BOŞLUK: müşteri/defter listeleri için cross-tenant testi vardı, SİPARİŞ listesi için yoktu.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $idA = $this->tohumla($a, 'a');
        $idB = $this->tohumla($b, 'b');

        $liste = $this->data()->orders($a['tenant']->id);
        $idler = collect($liste->items())->pluck('id')->all();

        $this->assertSame([$idA['siparis']], $idler, 'A yalnız kendi siparişini görmeli.');
        $this->assertNotContains($idB['siparis'], $idler, 'B\'nin siparişi A listesine SIZMAMALI.');
        $this->assertSame(1, $liste->total(), 'Toplam sayı da tek bayiye ait olmalı.');

        // Süzgeçli hâlde de sızmaz (filtre, tenant kısıtını gevşetmemeli).
        $suzgecli = $this->data()->orders($a['tenant']->id, ['durum' => 'open']);
        $this->assertNotContains($idB['siparis'], collect($suzgecli->items())->pluck('id')->all());
    }

    #[Test]
    public function urun_listesi_ve_tek_urun_baska_bayiye_uzanmaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $idA = $this->tohumla($a, 'a');
        $idB = $this->tohumla($b, 'b');

        // Ada göre arama: iki bayide de AYNI ad var; filtre yoksa ikisi de gelir.
        $liste = $this->data()->products($a['tenant']->id, self::ORTAK_URUN);
        $idler = collect($liste->items())->pluck('id')->all();
        $this->assertSame([$idA['urun']], $idler, 'Aynı adlı ürün iki bayide varken A yalnız kendininkini görmeli.');

        // Barkod da iki bayide aynı — barkod aramasında da sızmamalı.
        $barkodla = $this->data()->products($a['tenant']->id, '8690000000001');
        $this->assertSame([$idA['urun']], collect($barkodla->items())->pluck('id')->all());

        // Tek ürün sorgusu: B'nin ürünü A bağlamında SORULSA da null döner.
        $this->assertNotNull($this->data()->product($a['tenant']->id, $idA['urun']));
        $this->assertNull($this->data()->product($a['tenant']->id, $idB['urun']),
            'B\'nin ürünü A bağlamında bulunmamalı — düzenleme formu başka bayinin ürününü açamaz.');
    }

    #[Test]
    public function musteri_detayi_ve_aramasi_baska_bayiye_uzanmaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $idA = $this->tohumla($a, 'a');
        $idB = $this->tohumla($b, 'b');

        // B'nin müşterisi A bağlamında yok.
        $this->assertNotNull($this->data()->customerDetail($a['tenant']->id, $idA['musteri']));
        $this->assertNull($this->data()->customerDetail($a['tenant']->id, $idB['musteri']),
            'B\'nin müşteri detayı A bağlamında açılmamalı.');

        // TELEFONLA arama en riskli yol: numara iki bayide de aynı ve arama bir ALT SORGUDAN geçiyor.
        // Alt sorguda tenant_id unutulsaydı A'nın ekranında B'nin müşterisi çıkardı.
        $telefonla = $this->data()->customers($a['tenant']->id, '5321112233');
        $this->assertSame([$idA['musteri']], collect($telefonla->items())->pluck('id')->all(),
            'Aynı numara iki bayide kayıtlıyken arama yalnız kendi bayisininkini getirmeli.');

        // Ada ve koda göre arama da aynı sınırda.
        $adla = $this->data()->customers($a['tenant']->id, self::ORTAK_AD);
        $this->assertSame([$idA['musteri']], collect($adla->items())->pluck('id')->all());

        $kodla = $this->data()->customers($a['tenant']->id, (string) $idB['kod']);
        $this->assertNotContains($idB['musteri'], collect($kodla->items())->pluck('id')->all(),
            'B\'nin müşteri KODUYLA arama B\'nin kaydını getirmemeli.');
    }

    #[Test]
    public function tam_telefon_numarasiyla_arama_ekrani_cokertmez(): void
    {
        // REGRESYON — bu testi yazarken bulunan gerçek kusur: `customers.code` int4'tür ve arama
        // rakam dizisini KOD olarak da soruyordu. 10 haneli bir telefon numarası int4'e sığmaz →
        // Postgres 22003 atar → ekran 500 verir. Yani destek ekibinin EN SIK yaptığı şey (çağrıda
        // gelen numarayı arama kutusuna yapıştırmak) paneli çökertiyordu.
        //
        // Mevcut arama testi 7 haneli bir parça ('9998877') kullandığı için sınırın altında kalmış
        // ve kusuru hiç görmemişti; burada tam numaranın her yazılışı denenir.
        $a = $this->makeTenant('a');
        $idA = $this->tohumla($a, 'a');

        foreach (['5321112233', '05321112233', '+90 532 111 22 33', '0532-111-22-33'] as $yazim) {
            $sonuc = $this->data()->customers($a['tenant']->id, $yazim);

            $this->assertSame([$idA['musteri']], collect($sonuc->items())->pluck('id')->all(),
                "Tam telefon numarası ('{$yazim}') müşteriyi bulmalı ve sorgu patlamamalı.");
        }

        // Kod araması ÇALIŞMAYA devam ediyor (dar düzeltme, işlevi kaldırmadı).
        $this->assertSame([$idA['musteri']], collect($this->data()->customers($a['tenant']->id, (string) $idA['kod'])->items())->pluck('id')->all(),
            'Müşteri koduna göre arama korunmalı.');

        // int4 sınırının hemen üstü/altı: sınır aritmetiği yanlışsa biri patlar.
        $this->assertSame(0, $this->data()->customers($a['tenant']->id, '2147483648')->total(), 'int4 üstü sayı sonuçsuz dönmeli, hata atmamalı.');
        $this->assertSame(0, $this->data()->customers($a['tenant']->id, '9999999999999999999999')->total(), 'Absürt uzunlukta rakam dizisi de patlatmamalı.');
    }

    #[Test]
    public function sekme_sayilari_yalnizca_kendi_bayisini_sayar(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $this->tohumla($a, 'a');
        $this->tohumla($b, 'b');
        $this->tohumla($b, 'b'); // B'de İKİ takım veri — sayılar karışırsa fark büyür

        $sayilar = $this->data()->sayilar($a['tenant']->id);

        $this->assertSame(1, $sayilar['musteri'], 'A tek müşteri saymalı (B\'nin ikisi karışmamalı).');
        $this->assertSame(1, $sayilar['siparis']);
        $this->assertSame(1, $sayilar['urun']);
        $this->assertSame(1, $sayilar['defter']);
    }

    // --- CSV dışa aktarım ---------------------------------------------------------------

    #[Test]
    public function siparis_csvsi_baska_bayinin_siparisini_icermez(): void
    {
        // BOŞLUK: müşteri CSV'si için cross-tenant testi vardı, SİPARİŞ CSV'si için yoktu —
        // oysa dışa aktarım ekrandan daha tehlikelidir: dosya diske iner ve elden ele dolaşır.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $this->tohumla($a, 'a');
        $this->tohumla($b, 'b');

        $csv = $this->csv()->siparisler($a['tenant']->id);

        $this->assertStringContainsString('notu-a', $csv, 'A\'nın siparişi dosyada olmalı.');
        $this->assertStringNotContainsString('notu-b', $csv, 'B\'nin siparişi A\'nın dosyasına SIZMAMALI.');

        // Satır sayısı da tutmalı: içerik eşleşmesi bir satırı kaçırabilir, sayım kaçırmaz.
        $satirlar = array_values(array_filter(explode("\n", trim($csv))));
        $this->assertCount(2, $satirlar, 'Başlık + tek veri satırı beklenir.');
    }

    #[Test]
    public function siparis_csvsinde_de_formul_enjeksiyonu_kacirilir(): void
    {
        // Müşteri CSV'sinde kaçış testi vardı; sipariş CSV'si müşteri ADINI ayrı bir sorgudan
        // (JOIN) getirir ve kendi kaçış yolundan geçer — ayrıca kanıtlanmalı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $musteri = $this->customerUpsert(['name' => '=SUM(1+1)']);
        $mid = $musteri['payload']['id'];
        $this->pushEvents($token, [$musteri])->assertOk();
        $this->pushEvents($token, [$this->orderCreated([$this->line()], ['customer_id' => $mid, 'note' => '@komut'])])->assertOk();

        $csv = $this->csv()->siparisler($a['tenant']->id);

        $this->assertStringContainsString("'=SUM(1+1)", $csv, 'Formülle başlayan müşteri adı sipariş CSV\'sinde de kaçırılmalı.');
        $this->assertStringContainsString("'@komut", $csv, 'Sipariş notu da kullanıcı girdisidir; kaçırılmalı.');
        $this->assertStringNotContainsString(';=SUM(1+1)', $csv, 'Kaçırılmamış formül hücresi kalmamalı.');
    }

    #[Test]
    public function csv_indirme_route_lari_baska_bayinin_verisini_dondurmez(): void
    {
        // Servis seviyesinde filtre doğru olsa bile route yanlış tenant'ı geçirebilir; uçtan uca.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $this->tohumla($a, 'a');
        $this->tohumla($b, 'b');

        $this->actingAs($this->makeAdmin(), 'admin');

        $musteriCsv = $this->get(route('panel.tenant.csv.musteriler', $a['tenant']->id))->assertOk()->getContent();
        $siparisCsv = $this->get(route('panel.tenant.csv.siparisler', $a['tenant']->id))->assertOk()->getContent();

        foreach ([$musteriCsv, $siparisCsv] as $icerik) {
            $this->assertCount(2, array_values(array_filter(explode("\n", trim((string) $icerik)))),
                'İndirilen dosyada başlık + tek veri satırı olmalı.');
        }
        $this->assertStringNotContainsString('notu-b', (string) $siparisCsv, 'B\'nin siparişi A\'nın dosyasına sızmamalı.');
    }
}
