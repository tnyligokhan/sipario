<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\TenantDetail;
use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Tenant;
use App\Panel\PanelWriteService;
use App\Support\Provisioning;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * FAZ 5c-3 · D3 — müşteri/ürün yazmanın EKRAN tarafı (bayi detayındaki formlar).
 *
 * Servis katmanının kuralları PanelWriteTest'tedir; burada ekranın o kurallara doğru bağlandığı
 * sınanır: doğrulama kullanıcıya dönüyor mu, başarısız yazımda form AÇIK kalıyor mu (girilen veri
 * kaybolmasın), lira→kuruş dönüşümü doğru mu, düzenleme formu mevcut değerlerle doluyor mu.
 */
class PanelWriteUiTest extends ApiTestCase
{
    private function yazici(): PanelWriteService
    {
        return new PanelWriteService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Yazan Admin', 'email' => 'yazan-ui@sipario.test',
            'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /** Owner ile satır okuma (RLS dışı doğrulama). */
    private function musteriOku(string $id): ?Customer
    {
        return Provisioning::asOwner(fn () => Customer::query()->find($id));
    }

    #[Test]
    public function ekrandan_musteri_eklenir_ve_listede_gorunur(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc')
            ->assertSet('musteriFormAcik', true)
            ->set('musteriForm.ad', 'Ekrandan Ayşe')
            ->set('musteriForm.telefon', '0532 111 22 33')
            ->set('musteriForm.adres', 'Şirinyalı Mah.')
            ->call('musteriKaydet')
            ->assertSet('musteriFormAcik', false)
            ->assertSee('Müşteri kaydedildi.')
            ->assertSee('Ekrandan Ayşe')
            ->assertSee('+905321112233');
    }

    #[Test]
    public function ekranda_bos_ad_dogrulamayla_reddedilir_ve_kayit_olusmaz(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc')
            ->set('musteriForm.ad', '')
            ->call('musteriKaydet')
            ->assertHasErrors('musteriForm.ad');

        $this->assertSame(0, Provisioning::asOwner(fn () => Customer::query()->count()));
    }

    #[Test]
    public function ekranda_kilitli_bayide_yazma_denemesi_hata_gosterir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)
            ->update(['status' => 'locked', 'locked_at' => now()->subMinute(), 'valid_until' => now()->subDay()]));
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc')
            ->set('musteriForm.ad', 'Kilitliyken')
            ->call('musteriKaydet')
            ->assertSee('Aboneliğiniz sona erdi', false)   // sunucunun kilit mesajı kullanıcıya ulaşmalı
            // Yazılamayan form KAPANMAMALI — kullanıcı doldurduğu veriyi kaybetmesin.
            ->assertSet('musteriFormAcik', true);

        $this->assertSame(0, Provisioning::asOwner(fn () => Customer::query()->count()));
    }

    #[Test]
    public function ekrandan_urun_eklenir_fiyat_liradan_kurusa_cevrilir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'urunler')
            ->call('urunFormAc')
            ->set('urunForm.ad', '19L Damacana')
            ->set('urunForm.fiyat', '45,50')
            ->set('urunForm.birim', 'adet')
            ->call('urunKaydet')
            ->assertSee('Ürün kaydedildi.');

        $urun = Provisioning::asOwner(fn () => Product::query()->first());
        $this->assertSame(4550, $urun->unit_price_kurus, 'Lira metni kuruşa çevrilmeli (virgül ondalık).');
    }

    #[Test]
    public function ekrandan_urun_pasiflestirilir_ve_geri_acilir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $u = $this->yazici()->urunKaydet($a['tenant']->id, ['ad' => 'Damacana', 'fiyat_kurus' => 4500], $admin->id);
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'urunler')
            ->call('urunAktiflik', $u['id'], false)
            ->assertSee('Ürün pasifleştirildi.');
        $this->assertFalse(Provisioning::asOwner(fn () => Product::query()->find($u['id']))->is_active);

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'urunler')
            ->call('urunAktiflik', $u['id'], true)
            ->assertSee('Ürün etkinleştirildi.');
        $this->assertTrue(Provisioning::asOwner(fn () => Product::query()->find($u['id']))->is_active);
    }

    #[Test]
    public function ekrandan_kara_liste_acilip_kapanir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $m = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Sorunlu Müşteri'], $admin->id);
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriKaraListe', $m['id'], true)
            ->assertSee('kara listeye alındı')
            ->assertSee('kara liste');
        $this->assertNotNull($this->musteriOku($m['id'])->blacklisted_at);

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriKaraListe', $m['id'], false)
            ->assertSee('kara listeden çıkarıldı');
        $this->assertNull($this->musteriOku($m['id'])->blacklisted_at);
    }

    #[Test]
    public function duzenleme_formu_mevcut_degerlerle_dolar(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $m = $this->yazici()->musteriKaydet($a['tenant']->id, [
            'ad' => 'Ayşe', 'telefon' => '05321112233', 'adres' => 'Şirinyalı Mah.', 'bolge' => 'Muratpaşa',
        ], $admin->id);
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc', $m['id'])
            ->assertSet('musteriForm.musteriId', $m['id'])
            ->assertSet('musteriForm.ad', 'Ayşe')
            ->assertSet('musteriForm.telefon', '+905321112233')
            ->assertSet('musteriForm.adres', 'Şirinyalı Mah.')
            ->assertSet('musteriForm.bolge', 'Muratpaşa');
    }
}
