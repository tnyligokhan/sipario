<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\Login;
use App\Models\AdminUser;
use App\Support\Provisioning;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-3 — GÜVENLİK İNCELEMESİ bulgularının regresyon testleri.
 *
 * Buradaki üç konu da 5c-3'ün eklediği yetenekten DEĞİL, o yeteneğin değiştirdiği RİSKTEN doğdu:
 * panel artık bütün bayilerin müşteri adını/telefonunu/adresini gösteriyor ve müşteri/ürün yazıyor.
 * Aynı açıklar 5c-1'de de vardı ama hedefin değeri düşüktü; şimdi değil.
 */
class PanelGuvenlikTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function makeAdmin(string $email): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Güvenlik Testi', 'email' => $email,
            'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    // --- Kaba kuvvet sınırı -------------------------------------------------------------

    #[Test]
    public function panel_girisinde_kaba_kuvvet_denemeleri_sinirlanir(): void
    {
        // Mobil giriş `throttle:login` ile korunuyordu, panel korunmuyordu — oysa panel hesabı
        // BYPASSRLS'tir ve TÜM bayilerin kişisel verisini görür. Sınır bileşenin İÇİNDEDİR çünkü
        // Livewire eylemi `/livewire/update`e gider ve route'a yazılan `throttle:` onu görmez.
        $this->makeAdmin('brute@sipario.test');

        for ($i = 0; $i < 5; $i++) {
            Livewire::test(Login::class)
                ->set('email', 'brute@sipario.test')
                ->set('password', 'yanlis')
                ->call('authenticate')
                ->assertSee('Giriş bilgileri hatalı.');
        }

        // 6. deneme DOĞRU parolayla yapılsa bile reddedilir: sınır kimliğe bağlıdır, parolaya değil.
        Livewire::test(Login::class)
            ->set('email', 'brute@sipario.test')
            ->set('password', 'panel-secret')
            ->call('authenticate')
            ->assertSee('Çok fazla başarısız deneme');

        $this->assertFalse(Auth::guard('admin')->check(), 'Sınır dolduğunda oturum AÇILMAMALI.');
    }

    #[Test]
    public function sinir_mesru_kullaniciyi_kilitlemez_ve_basarili_giris_sayaci_temizler(): void
    {
        // Sınırın işe yaraması kadar önemli olan: parolasını birkaç kez yanlış yazan gerçek
        // kullanıcıyı dışarıda bırakmaması. Dördüncü denemeden sonra doğru parola İÇERİ ALIR.
        $this->makeAdmin('temiz@sipario.test');

        for ($i = 0; $i < 4; $i++) {
            Livewire::test(Login::class)
                ->set('email', 'temiz@sipario.test')
                ->set('password', 'yanlis')
                ->call('authenticate');
        }

        Livewire::test(Login::class)
            ->set('email', 'temiz@sipario.test')
            ->set('password', 'panel-secret')
            ->call('authenticate')
            ->assertRedirect(route('panel.dashboard'));

        $this->assertTrue(Auth::guard('admin')->check(), 'Doğru parola sınıra takılmamalı.');
    }

    // --- Toplu kişisel veri çıkışının denetim izi (KVKK) --------------------------------

    #[Test]
    public function toplu_disa_aktarimlar_denetim_izi_birakir(): void
    {
        // Panelin en yüksek hacimli kişisel veri çıkışı bu üç route'tur: tek istekte bir bayinin
        // TÜM müşteri adı/telefonu/adresi iner. Müşteri EKLEMEK günlüğe düşerken tüm listeyi
        // İNDİRMEK görünmüyordu — hesap verebilirlik açısından ters orantı.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin('export@sipario.test');
        $this->actingAs($admin, 'admin');

        $this->get(route('panel.tenant.export', $a['tenant']->id))->assertOk();
        $this->get(route('panel.tenant.csv.musteriler', $a['tenant']->id))->assertOk();
        $this->get(route('panel.tenant.csv.siparisler', $a['tenant']->id))->assertOk();

        $kayitlar = DB::connection('pgsql_panel')->table('panel_audit')
            ->where('tenant_id', $a['tenant']->id)
            ->where('action', 'export')
            ->orderBy('detail')
            ->get();

        $this->assertSame(
            ['csv_musteriler', 'csv_siparisler', 'json'],
            $kayitlar->pluck('detail')->all(),
            'Üç dışa aktarım yolunun HEPSİ iz bırakmalı.',
        );

        foreach ($kayitlar as $kayit) {
            $this->assertSame($admin->id, $kayit->admin_user_id, 'Kimin indirdiği kaydedilmeli.');
        }
    }

    #[Test]
    public function disa_aktarim_denetimi_kisisel_veri_degeri_yazmaz(): void
    {
        // panel_audit'in KVKK-nötr sözleşmesi (kırmızı çizgi #4): günlük NE yapıldığını yazar,
        // NE indirildiğini değil. Denetim kaydı yeni bir sızıntı yüzeyine dönüşmemeli.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin('kvkk@sipario.test');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Ayşe Yılmaz'])])->assertOk();

        $this->actingAs($admin, 'admin');
        $this->get(route('panel.tenant.csv.musteriler', $a['tenant']->id))->assertOk();

        $detay = (string) DB::connection('pgsql_panel')->table('panel_audit')
            ->where('action', 'export')->value('detail');

        $this->assertStringNotContainsString('Ayşe', $detay, 'Müşteri adı denetim kaydına yazılmamalı.');
        $this->assertSame('csv_musteriler', $detay);
    }

    // --- Tarayıcı güvenlik başlıkları ---------------------------------------------------

    #[Test]
    public function panel_sayfalari_guvenlik_basliklari_tasir(): void
    {
        // F3'te başlıklar yalnız `api` grubuna eklenmişti (o sırada tarayıcı yüzeyi yoktu).
        // Panel geldiğinde çerçeveye gömülebilir kaldı: oturumu açık bir admin'e görünmez bir
        // iframe üzerinden bayi kilitletmek/patron şifresi sıfırlatmak tek tıklık Livewire
        // düğmeleridir.
        $this->get(route('panel.login'))
            ->assertOk()
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('X-Content-Type-Options', 'nosniff');

        $admin = $this->makeAdmin('basliklar@sipario.test');
        $this->actingAs($admin, 'admin');

        $this->get(route('panel.dashboard'))
            ->assertOk()
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('X-Content-Type-Options', 'nosniff');
    }
}
