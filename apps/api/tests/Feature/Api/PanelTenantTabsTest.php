<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\TenantDetail;
use App\Models\AdminUser;
use App\Panel\PanelTenantDataService;
use App\Panel\TenantAdminService;
use App\Support\Provisioning;
use Illuminate\Support\Str;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-3 · D2 — bayi detayının SEKMELİ iş verisi görünümleri (müşteri/sipariş/defter/ürün/denetim).
 * Hepsi SALT-OKUNUR.
 *
 * En kritik testler cross-tenant olanlardır: panel rolü BYPASSRLS'tir, yani RLS yedeği YOKTUR ve
 * B bayisinin verisinin A'nın sekmesine sızmasını yalnız servisteki açık `tenant_id` filtreleri
 * önler. Bir filtre unutulursa buradaki testler kırılır.
 */
class PanelTenantTabsTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function data(): PanelTenantDataService
    {
        return new PanelTenantDataService('pgsql_panel');
    }

    private function makeAdmin(string $email = 'tabs-admin@sipario.test'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Sekme Admin', 'email' => $email, 'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /**
     * Bir bayiye müşteri + telefon + ürün + sipariş + defter tohumlar (üretim yolu: push API).
     *
     * @return array{musteri: string, urun: string, siparis: string}
     */
    private function veriTohumla(string $token, string $ad, string $telefon): array
    {
        $musteriId = (string) Str::uuid7();
        $urunId = (string) Str::uuid7();
        $siparisId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $this->customerUpsert(['id' => $musteriId, 'name' => $ad]),
            $this->event('product', 'upsert', [
                'id' => $urunId, 'name' => $ad.' Damacana', 'unit_price_kurus' => 4500, 'barcode' => '869'.substr($telefon, -6),
            ]),
        ])->assertOk();

        $this->pushEvents($token, [
            $this->event('customer_phone', 'upsert', [
                'id' => (string) Str::uuid7(), 'customer_id' => $musteriId,
                'phone_e164' => $telefon, 'is_primary' => true,
            ]),
            $this->orderCreated([$this->line(['product_id' => $urunId])], ['id' => $siparisId, 'customer_id' => $musteriId]),
        ])->assertOk();

        $this->pushEvents($token, [
            $this->ledgerEntry(['customer_id' => $musteriId, 'entry_type' => 'debit', 'amount_kurus' => 9000, 'related_order_id' => $siparisId]),
        ])->assertOk();

        return ['musteri' => $musteriId, 'urun' => $urunId, 'siparis' => $siparisId];
    }

    #[Test]
    public function musteri_listesi_bakiyeyi_telefonu_ve_son_siparisi_getirir(): void
    {
        $a = $this->makeTenant('a');
        $ids = $this->veriTohumla($this->tokenFor($a['patron']), 'Ayşe Yılmaz', '+905321112233');

        $liste = $this->data()->customers($a['tenant']->id);
        $this->assertSame(1, $liste->total());

        $satir = $liste->items()[0];
        $this->assertSame('Ayşe Yılmaz', $satir->name);
        $this->assertSame('+905321112233', $satir->telefon);
        $this->assertSame(9000, (int) $satir->balance_kurus, 'Bakiye defterden türeyen önbellekten okunmalı.');
        $this->assertNotNull($satir->son_siparis);
        $this->assertNotNull($satir->code, 'Müşteri sıra kodu listede görünmeli.');
        $this->assertSame($ids['musteri'], $satir->id);
    }

    #[Test]
    public function musteri_aramasi_ad_kod_ve_telefonun_son_hanelerine_bakar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $this->veriTohumla($token, 'Ayşe Yılmaz', '+905321112233');
        $this->veriTohumla($token, 'Mehmet Demir', '+905339998877');

        $kod = $this->data()->customers($a['tenant']->id)->items();
        $ayseKodu = collect($kod)->firstWhere('name', 'Ayşe Yılmaz')->code;

        $this->assertSame(1, $this->data()->customers($a['tenant']->id, 'ayşe')->total(), 'Ada göre arama (küçük/büyük harf duyarsız).');
        $this->assertSame(1, $this->data()->customers($a['tenant']->id, 'Demir')->total());
        $this->assertSame(1, $this->data()->customers($a['tenant']->id, '9998877')->total(), 'Telefonun son hanelerine göre arama.');
        $this->assertSame(1, $this->data()->customers($a['tenant']->id, (string) $ayseKodu)->total(), 'Müşteri koduna göre arama.');
        $this->assertSame(0, $this->data()->customers($a['tenant']->id, 'zzzyok')->total());
    }

    #[Test]
    public function musteri_listesi_baska_bayinin_musterisini_getirmez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $this->veriTohumla($this->tokenFor($a['patron']), 'A Müşterisi', '+905321112233');
        $idsB = $this->veriTohumla($this->tokenFor($b['patron']), 'B Müşterisi', '+905339998877');

        $liste = $this->data()->customers($a['tenant']->id);
        $adlar = collect($liste->items())->pluck('name')->all();

        $this->assertSame(['A Müşterisi'], $adlar, 'A yalnız kendi müşterisini görmeli (BYPASSRLS + açık filtre).');
        // B'nin müşterisi A'nın bayisi altında SORULSA da null döner (id global tekil olsa bile).
        $this->assertNull($this->data()->customerDetail($a['tenant']->id, $idsB['musteri']));
        $this->assertNotNull($this->data()->customerDetail($b['tenant']->id, $idsB['musteri']));
    }

    #[Test]
    public function musteri_detayi_iletisim_ve_son_siparisleri_verir(): void
    {
        $a = $this->makeTenant('a');
        $ids = $this->veriTohumla($this->tokenFor($a['patron']), 'Ayşe Yılmaz', '+905321112233');

        $detay = $this->data()->customerDetail($a['tenant']->id, $ids['musteri']);

        $this->assertNotNull($detay);
        $this->assertSame('Ayşe Yılmaz', $detay['musteri']->name);
        $this->assertCount(1, $detay['telefonlar']);
        $this->assertCount(1, $detay['siparisler']);
        $this->assertSame($ids['siparis'], $detay['siparisler'][0]->id);
    }

    #[Test]
    public function siparis_suzgeci_durum_ve_tarihe_gore_daraltir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $ids = $this->veriTohumla($token, 'Ayşe Yılmaz', '+905321112233');

        $hepsi = $this->data()->orders($a['tenant']->id);
        $this->assertSame(1, $hepsi->total());
        $this->assertSame('Ayşe Yılmaz', $hepsi->items()[0]->musteri, 'Sipariş satırı müşteri adını taşımalı.');

        $this->assertSame(1, $this->data()->orders($a['tenant']->id, ['durum' => 'open'])->total());
        $this->assertSame(0, $this->data()->orders($a['tenant']->id, ['durum' => 'delivered'])->total());

        // Teslim edilince 'delivered' süzgecine geçer.
        $this->pushEvents($token, [$this->orderEvent('delivered', ['order_id' => $ids['siparis'], 'payment_type' => 'nakit'])])->assertOk();
        $this->assertSame(1, $this->data()->orders($a['tenant']->id, ['durum' => 'delivered'])->total());

        // Tarih aralığı (TR günü).
        $bugun = now()->utc()->addHours(3)->format('Y-m-d');
        $this->assertSame(1, $this->data()->orders($a['tenant']->id, ['baslangic' => $bugun, 'bitis' => $bugun])->total());
        $this->assertSame(0, $this->data()->orders($a['tenant']->id, ['baslangic' => now()->addDays(5)->format('Y-m-d')])->total());
    }

    #[Test]
    public function defter_listesi_ve_ozeti_tipe_gore_calisir_cross_tenant_sizmaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $this->veriTohumla($this->tokenFor($a['patron']), 'A Müşterisi', '+905321112233');
        $this->veriTohumla($this->tokenFor($b['patron']), 'B Müşterisi', '+905339998877');

        $defter = $this->data()->ledger($a['tenant']->id);
        $this->assertSame(1, $defter->total(), 'A yalnız kendi defterini görmeli.');
        $this->assertSame('A Müşterisi', $defter->items()[0]->musteri);

        $this->assertSame(1, $this->data()->ledger($a['tenant']->id, ['tip' => 'debit'])->total());
        $this->assertSame(0, $this->data()->ledger($a['tenant']->id, ['tip' => 'payment'])->total());

        $ozet = $this->data()->ledgerOzet($a['tenant']->id);
        $this->assertSame(1, $ozet->count());
        $this->assertSame('debit', $ozet->first()->entry_type);
        $this->assertSame(9000, (int) $ozet->first()->toplam);
    }

    #[Test]
    public function urun_listesi_ada_ve_barkoda_gore_aranir(): void
    {
        $a = $this->makeTenant('a');
        $this->veriTohumla($this->tokenFor($a['patron']), 'Ayşe', '+905321112233');

        $this->assertSame(1, $this->data()->products($a['tenant']->id)->total());
        $this->assertSame(1, $this->data()->products($a['tenant']->id, 'damacana')->total());
        $this->assertSame(1, $this->data()->products($a['tenant']->id, '869')->total(), 'Barkod parçasıyla aranabilmeli.');
        $this->assertSame(0, $this->data()->products($a['tenant']->id, 'yokboyle')->total());
    }

    #[Test]
    public function denetim_sekmesi_yalnizca_o_bayinin_panel_kayitlarini_gosterir(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $admin = $this->makeAdmin();
        $service = new TenantAdminService('pgsql_panel');

        $service->lock($a['tenant']->id, $admin->id);
        $service->unlock($a['tenant']->id, $admin->id);
        $service->suspend($b['tenant']->id, $admin->id);

        $kayitlar = $this->data()->audit($a['tenant']->id);
        $eylemler = collect($kayitlar->items())->pluck('action')->all();

        $this->assertSame(2, $kayitlar->total());
        $this->assertEqualsCanonicalizing(['lock', 'unlock'], $eylemler);
        $this->assertNotContains('suspend', $eylemler, "B'nin eylemi A'nın denetim sekmesine sızmamalı.");
        $this->assertSame('Sekme Admin', $kayitlar->items()[0]->admin, 'Satırda uuid değil admin adı görünmeli.');
    }

    #[Test]
    public function sekme_sayilari_dogru(): void
    {
        $a = $this->makeTenant('a');
        $this->veriTohumla($this->tokenFor($a['patron']), 'Ayşe', '+905321112233');

        $sayilar = $this->data()->sayilar($a['tenant']->id);

        $this->assertSame(1, $sayilar['musteri']);
        $this->assertSame(1, $sayilar['siparis']);
        $this->assertSame(1, $sayilar['defter']);
        $this->assertSame(1, $sayilar['urun']);
        $this->assertSame(0, $sayilar['denetim']);
    }

    #[Test]
    public function sayfalama_ikinci_sayfayi_dogru_getirir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $olaylar = [];
        for ($i = 1; $i <= 25; $i++) {
            $olaylar[] = $this->customerUpsert(['name' => sprintf('Müşteri %02d', $i)]);
        }
        $this->pushEvents($token, $olaylar)->assertOk();

        $sayfa1 = $this->data()->customers($a['tenant']->id, '', false, 20);
        $this->assertSame(25, $sayfa1->total());
        $this->assertCount(20, $sayfa1->items());
        $this->assertSame(2, $sayfa1->lastPage());
    }

    // --- Ekran (Livewire) ---------------------------------------------------------------

    #[Test]
    public function sekmeler_ekranda_gezilebilir_ve_dogru_icerigi_cizer(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->veriTohumla($this->tokenFor($a['patron']), 'Ayşe Yılmaz', '+905321112233');

        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->assertSee('Abonelik')                       // varsayılan sekme: Özet
            ->call('sekmeSec', 'musteriler')
            ->assertSee('Ayşe Yılmaz')
            ->call('sekmeSec', 'siparisler')
            ->assertSee('SALT-OKUNUR')
            ->call('sekmeSec', 'defter')
            ->assertSee('debit')
            ->call('sekmeSec', 'urunler')
            ->assertSee('Ayşe Yılmaz Damacana')
            ->call('sekmeSec', 'denetim')
            ->assertSee('Denetim');
    }

    #[Test]
    public function bilinmeyen_sekme_ozete_duser(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'uydurma')
            ->assertSet('sekme', 'ozet');
    }

    #[Test]
    public function musteri_detayi_ekranda_acilip_kapanir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $ids = $this->veriTohumla($this->tokenFor($a['patron']), 'Ayşe Yılmaz', '+905321112233');
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriAc', $ids['musteri'])
            ->assertSet('acikMusteri', $ids['musteri'])
            ->assertSee('borçlu')
            ->call('musteriAc', $ids['musteri'])
            ->assertSet('acikMusteri', null);
    }
}
