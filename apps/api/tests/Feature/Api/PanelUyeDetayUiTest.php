<?php

namespace Tests\Feature\Api;

use App\Enums\TenantStatus;
use App\Livewire\Panel\Dashboard;
use App\Livewire\Panel\TenantDetail;
use App\Models\AdminUser;
use App\Models\Tenant;
use App\Models\TenantNote;
use App\Support\Provisioning;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * ÜYE DETAYI EKRANI (yeni tasarım) — iki sütunlu Özet · BRIEF zorunlulukları · deneme uzatma ·
 * iptal · kurye açma · yetki kapıları. Giriş/Dashboard/Üyeler ayrı dosyada: `PanelCekirdekUiTest`.
 *
 * İki soru burada: yetki kapısı EYLEMİN İÇİNDE mi (Blade'de düğmeyi gizlemek denetim değildir),
 * ve REDDEDİLEN deneme denetim günlüğüne düşüyor mu.
 */
class PanelUyeDetayUiTest extends ApiTestCase
{
    private function admin(string $rol = 'superadmin', string $email = 'detay@sipario.test'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Detay Admin', 'email' => $email, 'password' => 'panel-secret', 'role' => $rol,
        ]));
    }

    /** @return Collection<int, \stdClass> */
    private function denetim(string $eylem)
    {
        return DB::connection('pgsql_panel')->table('panel_audit')->where('action', $eylem)->get();
    }

    #[Test]
    public function uye_detayi_tasarimin_iki_sutunlu_duzenini_basar(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->assertOk()
            ->assertSee('Firma Bilgileri')
            ->assertSee('Abonelik')
            ->assertSee('Ek Paketler')
            ->assertSee('Ödeme Geçmişi')
            ->assertSee('Notlar')
            ->assertSee('Henüz ödeme kaydı yok.')
            ->assertSee('Henüz not yok.');
    }

    #[Test]
    public function uye_detayi_brief_in_zorunlu_yeteneklerini_de_basar(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->assertOk()
            ->assertSee('Boş/emanet takibi')            // modül aç/kapa
            ->assertSee('Patron Şifresini Sıfırla')     // patron parolası
            ->assertSee('Cihazlar')                     // cihaz listesi
            ->assertSee('Veri Aktarımı')                // kırmızı çizgi #5
            ->assertSee('Müşteri CSV Aktar')
            ->assertSee('Kurye Aç')
            ->assertSee('İptal Et');
    }

    #[Test]
    public function uye_detayi_disa_aktarim_kapisini_kapatmaz(): void
    {
        // BRIEF kırmızı çizgi #5. Route hazır olsa bile ekranda bağlantı yoksa kapı kapalıdır.
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->assertSee(route('panel.tenant.export', $a['tenant']->id), false)
            ->assertSee(route('panel.tenant.csv.musteriler', $a['tenant']->id), false)
            ->assertSee(route('panel.tenant.csv.siparisler', $a['tenant']->id), false);
    }

    #[Test]
    public function bozuk_uuid_404_verir_500_degil(): void
    {
        $this->actingAs($this->admin(), 'admin');

        $this->get('/panel/tenants/bu-bir-uuid-degil')->assertNotFound();
        $this->get(route('panel.tenant.import', 'bu-bir-uuid-degil'))->assertNotFound();
    }

    #[Test]
    public function not_ekleme_append_only_calisir(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->set('yeniNot', 'Telefonla arandı, haftaya ödeyecek.')
            ->call('notEkle')
            ->assertSet('yeniNot', '')
            ->assertSee('Telefonla arandı, haftaya ödeyecek.');

        $this->assertSame(1, Provisioning::asOwner(
            fn () => TenantNote::query()->where('tenant_id', $a['tenant']->id)->count()
        ));
    }

    #[Test]
    public function bos_not_kaydedilmez(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->set('yeniNot', '   ')
            ->call('notEkle')
            ->assertOk();

        $this->assertSame(0, Provisioning::asOwner(
            fn () => TenantNote::query()->where('tenant_id', $a['tenant']->id)->count()
        ));
    }

    #[Test]
    public function deneme_uzat_modali_hizli_secimle_uzatir(): void
    {
        $a = $this->denemeBayisi();
        $this->actingAs($this->admin(), 'admin');
        $once = Provisioning::asOwner(fn () => Tenant::query()->findOrFail($a)->trial_ends_at);

        Livewire::test(TenantDetail::class, ['tenant' => $a])
            ->call('uzatAc')
            ->assertSet('uzatAcik', true)
            ->call('hizliGun', 15)
            ->call('uzatKaydet')
            ->assertSet('uzatAcik', false);

        $sonra = Provisioning::asOwner(fn () => Tenant::query()->findOrFail($a)->trial_ends_at);
        $this->assertSame(15, (int) round($once->diffInDays($sonra)), 'Deneme 15 gün uzamalıydı.');
    }

    #[Test]
    public function deneme_uzat_modali_geri_giden_tarihi_reddeder_ve_denetime_yazar(): void
    {
        // Özel tarih mevcut bitişin GERİSİNDEyse bu bir uzatma değil sessiz KISALTMAdır.
        $a = $this->denemeBayisi();
        $this->actingAs($this->admin(), 'admin');
        $once = Provisioning::asOwner(fn () => Tenant::query()->findOrFail($a)->trial_ends_at);

        Livewire::test(TenantDetail::class, ['tenant' => $a])
            ->call('uzatAc')
            ->set('uzatOzelTarih', now()->subDay()->toDateString())
            ->call('uzatKaydet')
            ->assertSet('uzatAcik', true)
            ->assertSee('Yeni tarih mevcut deneme bitişinden sonra olmalı.');

        $sonra = Provisioning::asOwner(fn () => Tenant::query()->findOrFail($a)->trial_ends_at);
        $this->assertTrue($once->equalTo($sonra), 'Reddedilen uzatma tarihi değiştirmemeli.');
        $this->assertCount(1, $this->denetim('extend_trial_denied'));
    }

    #[Test]
    public function iptal_et_durumu_cancelled_yapar_ve_denetime_yazar(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])->call('iptalEt');

        $bayi = Provisioning::asOwner(fn () => Tenant::query()->findOrFail($a['tenant']->id));
        $this->assertSame(TenantStatus::Cancelled, $bayi->status);
        $this->assertNotNull($bayi->locked_at, 'İptal 5a kilidini de kurmalı (yazma kapanır).');
        $this->assertCount(1, $this->denetim('cancel'));
    }

    // --- Kurye açma ----------------------------------------------------------------------

    #[Test]
    public function kurye_hesabi_acilir(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('kuryeAc')
            ->set('kuryeAd', 'Mehmet Demir')
            ->set('kuryeKullanici', 'mehmet')
            ->set('kuryeParola', 'kurye-parolasi')
            ->call('kuryeKaydet')
            ->assertSet('kuryeAcik', false)
            ->assertHasNoErrors();

        $this->assertCount(1, $this->denetim('create_courier'));
    }

    #[Test]
    public function kota_dolu_kurye_acilmaz_ve_red_denetime_duser(): void
    {
        // `makeTenant` zaten bir kurye açıyor; limiti 1'e çekince kota DOLUdur.
        $a = $this->makeTenant('a');
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)->update(['courier_limit' => 1]));
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('kuryeAc')
            ->set('kuryeAd', 'Fazladan Kurye')
            ->set('kuryeKullanici', 'fazladan')
            ->set('kuryeParola', 'kurye-parolasi')
            ->call('kuryeKaydet')
            ->assertSet('kuryeAcik', true)
            ->assertSee('Kurye hesabı kotası dolu');

        $this->assertCount(0, $this->denetim('create_courier'));
        $this->assertCount(1, $this->denetim('create_courier_denied'));
    }

    #[Test]
    public function gecersiz_kullanici_adi_reddedilir(): void
    {
        // users.username DB CHECK altında; sınır formda durmazsa Postgres hatası 500 olur.
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('kuryeAc')
            ->set('kuryeAd', 'Büyük Harf')
            ->set('kuryeKullanici', 'Mehmet Demir')
            ->set('kuryeParola', 'kurye-parolasi')
            ->call('kuryeKaydet')
            ->assertHasErrors('kuryeKullanici')
            ->assertSet('kuryeAcik', true);
    }

    #[Test]
    public function destek_rolu_abonelik_eylemlerini_calistiramaz(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin('support', 'destek@sipario.test'), 'admin');

        $eylemler = ['uzatAc', 'activate', 'lock', 'unlock', 'suspend', 'iptalEt', 'resetPassword', 'kuryeAc'];
        foreach ($eylemler as $eylem) {
            Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
                ->call($eylem)
                ->assertForbidden();
        }

        $bayi = Provisioning::asOwner(fn () => Tenant::query()->findOrFail($a['tenant']->id));
        $this->assertSame(TenantStatus::Active, $bayi->status, 'Destek rolü durumu değiştirememeli.');
    }

    #[Test]
    public function reddedilen_yetkisiz_deneme_denetime_duser(): void
    {
        // Önceki incelemenin kapatılmayan bulgusu: yalnız BAŞARILI eylemler iz bırakıyordu.
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin('support', 'destek2@sipario.test'), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('activate')
            ->assertForbidden();

        $kayitlar = $this->denetim('activate_denied');
        $this->assertCount(1, $kayitlar);
        $this->assertSame('yetkisiz', $kayitlar->first()->detail);
        $this->assertSame($a['tenant']->id, $kayitlar->first()->tenant_id);
    }

    #[Test]
    public function denetim_kaydi_not_metnini_tasimaz(): void
    {
        // KVKK (kırmızı çizgi #4): not metni serbesttir, denetim günlüğü ona kapalıdır.
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->set('yeniNot', 'Ayşe Hanım 0532 111 22 33 numarasından aradı.')
            ->call('notEkle');

        foreach ($this->denetim('tenant_note') as $kayit) {
            $this->assertStringNotContainsString('Ayşe', (string) $kayit->detail);
            $this->assertStringNotContainsString('0532', (string) $kayit->detail);
        }
    }

    /** Denemedeki bir bayi yaratır ve id`sini döner. */
    private function denemeBayisi(): string
    {
        $a = $this->makeTenant('a');

        Provisioning::asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)->update([
            'status' => TenantStatus::Trial->value,
            'trial_ends_at' => now()->addDays(10),
            'valid_until' => now()->addDays(10),
        ]));

        return (string) $a['tenant']->id;
    }
}
