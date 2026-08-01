<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\Login;
use App\Livewire\Panel\TenantDetail;
use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\Product;
use App\Panel\PanelWriteService;
use App\Support\Provisioning;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use RuntimeException;
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

    // --- Düzenleme akışı upsert DEĞİLDİR (lead kararı) ----------------------------------

    #[Test]
    public function duzenlemede_bulunamayan_musteri_sessizce_yeni_kayit_yaratmaz(): void
    {
        // Eski davranış iki yalan söylüyordu: kullanıcıya "kaydedildi", denetime `customer_update` —
        // oysa ortada düzenlenen bir kayıt yok, YENİ bir müşteri doğmuştu. Kopya kayıt sahada en
        // pahalı kirliliktir ve sessizce oluşuyordu.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin('hayalet@sipario.test');

        try {
            (new PanelWriteService('pgsql_panel'))->musteriKaydet($a['tenant']->id, [
                'id' => (string) Str::uuid7(), 'ad' => 'Hayalet Müşteri',
            ], $admin->id);
            $this->fail('Bulunamayan id ile düzenleme BAŞARISIZ olmalıydı.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('bulunamadı', $e->getMessage());
        }

        $this->assertSame(0, Provisioning::asOwner(fn () => Customer::query()->count()),
            'Bulunamayan id kopya müşteri yaratmamalı.');
        $this->assertSame(0, DB::connection('pgsql_panel')->table('panel_audit')
            ->where('action', 'customer_update')->count(),
            'Yapılmamış bir düzenleme denetime yazılmamalı.');
    }

    #[Test]
    public function duzenlemede_bulunamayan_urun_sessizce_yeni_kayit_yaratmaz(): void
    {
        // Ürün tarafında birebir aynı desen vardı; tek kardeşi düzeltip diğerini bırakmak
        // kuralı yarım uygulamak olurdu.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin('hayalet-urun@sipario.test');

        try {
            (new PanelWriteService('pgsql_panel'))->urunKaydet($a['tenant']->id, [
                'id' => (string) Str::uuid7(), 'ad' => 'Hayalet Ürün', 'fiyat_kurus' => 1000,
            ], $admin->id);
            $this->fail('Bulunamayan id ile ürün düzenleme BAŞARISIZ olmalıydı.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('bulunamadı', $e->getMessage());
        }

        $this->assertSame(0, Provisioning::asOwner(fn () => Product::query()->count()));
        $this->assertSame(0, DB::connection('pgsql_panel')->table('panel_audit')
            ->where('action', 'product_update')->count());
    }

    #[Test]
    public function ekranda_bulunamayan_kayit_hata_gosterir_500_vermez(): void
    {
        // Servis artık fırlatıyor; ekranın bunu KULLANICIYA çevirdiğini de görmek gerek —
        // yoksa düzeltme 500 hatasına dönüşmüş olurdu.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin('ekran-hayalet@sipario.test');
        $this->actingAs($admin, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc')
            ->set('musteriForm.musteriId', (string) Str::uuid7())
            ->set('musteriForm.ad', 'Hayalet')
            ->call('musteriKaydet')
            ->assertOk()
            ->assertSee('bulunamadı')
            ->assertDontSee('Müşteri kaydedildi.');

        $this->assertSame(0, Provisioning::asOwner(fn () => Customer::query()->count()));
    }

    #[Test]
    public function aktarim_ekrani_olmayan_bayide_404_verir(): void
    {
        // Uydurma UUID ile sayfa açılıyor ve sayılar sıfır görünüyordu; kullanıcı boş bir bayiye
        // baktığını sanıyordu. Bayi detayı zaten 404 veriyor — iki panel sayfası aynı adrese
        // farklı cevap vermemeli.
        $admin = $this->makeAdmin('aktarim404@sipario.test');
        $this->actingAs($admin, 'admin');

        $this->get(route('panel.tenant.import', (string) Str::uuid7()))->assertNotFound();

        // Gerçek bayide sayfa açılmaya devam ediyor (kapı fazla dar değil).
        $a = $this->makeTenant('a');
        $this->get(route('panel.tenant.import', $a['tenant']->id))->assertOk();
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
