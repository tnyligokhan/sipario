<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\AdminUsers;
use App\Livewire\Panel\Login;
use App\Livewire\Panel\TenantDetail;
use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\Tenant;
use App\Panel\PanelAdminService;
use App\Panel\PanelWriteService;
use App\Support\Provisioning;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use RuntimeException;
use Tests\ApiTestCase;

/**
 * FAZ 5c-3 · D5 — panel hesap yönetimi, İKİ ROL ve genel denetim günlüğü.
 *
 * Rol ayrımının anlamı: `support` bayinin işine yardım edebilir (müşteri/ürün girişi) ama bayinin
 * ABONELİĞİNE, kilidine, patron şifresine ve panel hesaplarına dokunamaz. Testlerin ağırlığı bu
 * sınırın SUNUCUDA durduğunu göstermektedir — düğmeyi gizlemek yetki denetimi değildir.
 */
class PanelAdminTest extends ApiTestCase
{
    private function service(): PanelAdminService
    {
        return new PanelAdminService('pgsql_panel');
    }

    private function admin(string $rol = 'superadmin', string $email = 'super@sipario.test'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => $rol === 'superadmin' ? 'Süper Admin' : 'Destek Admin',
            'email' => $email, 'password' => 'panel-secret', 'role' => $rol,
        ]));
    }

    // --- Hesap yönetimi -----------------------------------------------------------------

    #[Test]
    public function hesap_eklenir_parola_bir_kez_doner_ve_denetime_deger_yazilmaz(): void
    {
        $super = $this->admin();

        $sonuc = $this->service()->ekle('Yeni Destek', 'Yeni@Sipario.TEST', 'support', $super->id);

        $this->assertSame('yeni@sipario.test', $sonuc['admin']->email, 'E-posta küçük harfe indirilmeli.');
        $this->assertSame('support', $sonuc['admin']->role);
        $this->assertGreaterThanOrEqual(12, strlen($sonuc['parola']));

        // Üretilen parola gerçekten çalışır.
        $this->assertTrue(Auth::guard('admin')->attempt([
            'email' => 'yeni@sipario.test', 'password' => $sonuc['parola'],
        ]));

        $detay = DB::connection('pgsql_panel')->table('panel_audit')->where('action', 'admin_create')->value('detail');
        $this->assertStringContainsString('admin:'.$sonuc['admin']->id, (string) $detay);
        $this->assertStringNotContainsString($sonuc['parola'], (string) $detay, 'Parola denetime YAZILMAMALI.');
    }

    #[Test]
    public function ayni_eposta_ikinci_kez_eklenemez(): void
    {
        $super = $this->admin();
        $this->service()->ekle('Destek', 'destek@sipario.test', 'support', $super->id);

        $this->expectException(RuntimeException::class);
        $this->service()->ekle('Başka Kişi', 'destek@sipario.test', 'support', $super->id);
    }

    #[Test]
    public function pasiflestirilen_hesap_giremez_ve_acik_oturumu_da_coker(): void
    {
        // Kapsam MODEL düzeyinde olduğu için hem giriş denemesi hem oturum çözümü etkilenir —
        // yalnız giriş ekranına kontrol koysaydık pasifleştirilen kişi tarayıcısı açıkken çalışmayı
        // sürdürürdü ve "pasifleştirdim" demek yanlış olurdu.
        $super = $this->admin();
        $destek = $this->admin('support', 'destek@sipario.test');

        $this->assertTrue(Auth::guard('admin')->attempt(['email' => 'destek@sipario.test', 'password' => 'panel-secret']));
        Auth::guard('admin')->logout();

        $this->service()->aktiflik($destek->id, false, $super->id);

        $this->assertFalse(
            Auth::guard('admin')->attempt(['email' => 'destek@sipario.test', 'password' => 'panel-secret']),
            'Pasif hesap giriş yapamamalı.'
        );

        // AÇIK OTURUM da çöker: session guard her istekte kullanıcıyı provider'dan ÇÖZER
        // (retrieveById) ve kapsam orada da geçerlidir. Bunu `actingAs` ile sınayamayız —
        // o, örneği doğrudan guard'a enjekte eder ve provider'a hiç uğramaz; yani üretimdeki
        // yolu atlar. Doğru sınama provider'ın kendisidir.
        $this->app['auth']->forgetGuards();
        $provider = Auth::guard('admin')->getProvider();
        $this->assertNull($provider->retrieveById($destek->id), 'Pasif hesap oturumdan çözülememeli.');
        $this->assertNotNull($provider->retrieveById($super->id), 'Aktif hesap çözülmeye devam etmeli.');

        // Geri açılınca yeniden girebilir.
        $this->service()->aktiflik($destek->id, true, $super->id);
        $this->app['auth']->forgetGuards();
        $this->assertTrue(Auth::guard('admin')->attempt(['email' => 'destek@sipario.test', 'password' => 'panel-secret']));
    }

    #[Test]
    public function hesap_silinmez_sadece_pasiflesir_ve_listede_kalir(): void
    {
        $super = $this->admin();
        $destek = $this->admin('support', 'destek@sipario.test');

        $this->service()->aktiflik($destek->id, false, $super->id);

        $idler = $this->service()->adminler()->pluck('id')->all();
        $this->assertContains($destek->id, $idler, 'Pasif hesap yönetim listesinde GÖRÜNMELİ.');
        $this->assertSame(2, DB::connection('pgsql_panel')->table('admin_users')->count(), 'Satır silinmemeli.');
    }

    #[Test]
    public function kendini_ve_son_superadmini_kilitleme_korumasi(): void
    {
        $super = $this->admin();

        // Kendi hesabını pasifleştiremez.
        try {
            $this->service()->aktiflik($super->id, false, $super->id);
            $this->fail('Kendi hesabını pasifleştirmek engellenmeliydi.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('Kendi hesabınızı', $e->getMessage());
        }

        // Başka bir superadmin de son superadmini kapatamaz/rolünü düşüremez.
        $ikinci = $this->admin('superadmin', 'ikinci@sipario.test');
        $this->service()->aktiflik($ikinci->id, false, $super->id); // artık tek aktif superadmin: $super

        try {
            $this->service()->rolDegistir($super->id, 'support', $ikinci->id);
            $this->fail('Son superadminin rolü düşürülememeliydi.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('Son aktif süper yönetici', $e->getMessage());
        }
    }

    #[Test]
    public function rol_degistirilebilir(): void
    {
        $super = $this->admin();
        $destek = $this->admin('support', 'destek@sipario.test');

        $this->service()->rolDegistir($destek->id, 'superadmin', $super->id);

        $this->assertSame('superadmin', AdminUser::on('pgsql_panel')->find($destek->id)->role);
        $this->assertSame(1, DB::connection('pgsql_panel')->table('panel_audit')->where('action', 'admin_role')->count());
    }

    // --- Rol kapıları -------------------------------------------------------------------

    #[Test]
    public function destek_rolu_abonelik_eylemlerini_calistiramaz(): void
    {
        $a = $this->makeTenant('a');
        $destek = $this->admin('support', 'destek@sipario.test');
        $this->actingAs($destek, 'admin');

        foreach (['extendTrial', 'activate', 'lock', 'unlock', 'suspend', 'resetPassword'] as $eylem) {
            Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
                ->call($eylem)
                ->assertForbidden();
        }

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('toggleModule', 'empty_tracking')
            ->assertForbidden();

        // Bayi hâlâ dokunulmamış.
        $tenant = $this->asOwner(fn () => Tenant::query()->find($a['tenant']->id));
        $this->assertSame('active', $tenant->status->value);
        $this->assertNull($tenant->locked_at);
    }

    #[Test]
    public function destek_rolu_musteri_ve_urun_girebilir(): void
    {
        // Ayrımın diğer yarısı: destek ekibi bayinin işine yardım EDEBİLMELİ.
        $a = $this->makeTenant('a');
        $destek = $this->admin('support', 'destek@sipario.test');
        $this->actingAs($destek, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc')
            ->set('musteriForm.ad', 'Destek Girdi')
            ->call('musteriKaydet')
            ->assertSee('Müşteri kaydedildi.');

        $this->assertSame(1, $this->asOwner(fn () => Customer::query()->count()));
    }

    #[Test]
    public function destek_rolu_ozet_sekmesinde_abonelik_dugmelerini_gormez(): void
    {
        $a = $this->makeTenant('a');
        $destek = $this->admin('support', 'destek@sipario.test');
        $this->actingAs($destek, 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->assertDontSee('Aboneliği Kaydet')
            ->assertDontSee('Patron Şifresini Sıfırla')
            ->assertSee('yalnız süper');
    }

    #[Test]
    public function hesap_yonetimi_ekrani_yalnizca_superadmine_acik(): void
    {
        $destek = $this->admin('support', 'destek@sipario.test');
        $this->actingAs($destek, 'admin');

        $this->get(route('panel.admins'))->assertForbidden();
        Livewire::test(AdminUsers::class)->assertForbidden();

        $this->app['auth']->forgetGuards();
        $super = $this->admin();
        $this->actingAs($super, 'admin');
        $this->get(route('panel.admins'))->assertOk()->assertSee('Panel Hesapları');
    }

    #[Test]
    public function hesap_ekranindan_hesap_acilir_ve_parola_bir_kez_gosterilir(): void
    {
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        Livewire::test(AdminUsers::class)
            ->set('ad', 'Yeni Destek')
            ->set('email', 'yeni@sipario.test')
            ->set('rol', 'support')
            ->call('ekle')
            ->assertSee('Yeni Destek eklendi.')
            ->assertSee('Bir kez gösterilir');

        $this->assertSame(2, DB::connection('pgsql_panel')->table('admin_users')->count());
    }

    // --- Genel denetim günlüğü ----------------------------------------------------------

    #[Test]
    public function genel_denetim_gunlugu_tum_bayileri_gosterir_ve_eyleme_gore_suzer(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $super = $this->admin();
        $yazici = new PanelWriteService('pgsql_panel');

        $yazici->musteriKaydet($a['tenant']->id, ['ad' => 'A Müşterisi'], $super->id);
        $yazici->musteriKaydet($b['tenant']->id, ['ad' => 'B Müşterisi'], $super->id);
        $this->service()->ekle('Destek', 'destek@sipario.test', 'support', $super->id);

        $hepsi = $this->service()->denetimGunlugu();
        $this->assertSame(3, $hepsi->total(), 'Günlük TÜM bayilerin eylemlerini göstermeli.');

        $bayiAdlari = collect($hepsi->items())->pluck('bayi')->filter()->all();
        $this->assertContains($a['tenant']->name, $bayiAdlari, 'Satırda ham uuid değil bayi adı görünmeli.');
        $this->assertContains($b['tenant']->name, $bayiAdlari);

        $suzulmus = $this->service()->denetimGunlugu(['eylem' => 'admin_create']);
        $this->assertSame(1, $suzulmus->total());
        $this->assertNull($suzulmus->items()[0]->tenant_id, 'Hesap yönetimi bayi-üstüdür.');

        $this->assertEqualsCanonicalizing(
            ['admin_create', 'customer_create'],
            $this->service()->eylemTurleri(),
            'Süzgeç listesi veriden türemeli (sabit liste bayatlar).'
        );
    }

    #[Test]
    public function denetim_ekrani_her_iki_role_de_acik(): void
    {
        $a = $this->makeTenant('a');
        $super = $this->admin();
        (new PanelWriteService('pgsql_panel'))->musteriKaydet($a['tenant']->id, ['ad' => 'Kayıt'], $super->id);

        $destek = $this->admin('support', 'destek@sipario.test');
        $this->actingAs($destek, 'admin');
        $this->get(route('panel.audit'))->assertOk()->assertSee('customer_create');

        $this->app['auth']->forgetGuards();
        $this->actingAs($super, 'admin');
        $this->get(route('panel.audit'))->assertOk()->assertSee('customer_create');
    }

    #[Test]
    public function denetim_ekrani_oturumsuz_acilmaz(): void
    {
        $this->get(route('panel.audit'))->assertRedirect(route('panel.login'));
        $this->get(route('panel.admins'))->assertRedirect(route('panel.login'));
    }

    // --- Konsol komutu ------------------------------------------------------------------

    #[Test]
    public function panel_admin_komutu_ilk_hesabi_kurar_ve_parolayi_bir_kez_basar(): void
    {
        $this->assertSame(0, DB::connection('pgsql_panel')->table('admin_users')->count());

        $this->artisan('panel:admin', ['name' => 'Gökhan', 'email' => 'Gokhan@Sipario.COM'])
            ->expectsOutputToContain('Panel yöneticisi oluşturuldu.')
            ->expectsOutputToContain('gokhan@sipario.com')
            ->assertSuccessful();

        $admin = AdminUser::on('pgsql_panel')->where('email', 'gokhan@sipario.com')->first();
        $this->assertNotNull($admin);
        $this->assertSame('superadmin', $admin->role, 'Varsayılan rol superadmin (ilk kurulum).');
    }

    #[Test]
    public function panel_admin_komutu_verilen_parolayla_giris_yapilabilir(): void
    {
        $this->artisan('panel:admin', [
            'name' => 'Destek', 'email' => 'destek@sipario.test',
            '--rol' => 'support', '--parola' => 'cok-guclu-parola-123',
        ])->assertSuccessful();

        $this->assertTrue(Auth::guard('admin')->attempt([
            'email' => 'destek@sipario.test', 'password' => 'cok-guclu-parola-123',
        ]));
        $this->assertSame('support', Auth::guard('admin')->user()->role);
    }

    #[Test]
    public function panel_admin_komutu_gecersiz_girdiyi_reddeder(): void
    {
        $this->artisan('panel:admin', ['name' => 'X', 'email' => 'gecersiz-eposta'])->assertFailed();
        $this->artisan('panel:admin', ['name' => 'X', 'email' => 'a@b.com', '--rol' => 'kral'])->assertFailed();
        $this->artisan('panel:admin', ['name' => 'X', 'email' => 'a@b.com', '--parola' => 'kisa'])->assertFailed();

        $this->assertSame(0, DB::connection('pgsql_panel')->table('admin_users')->count());
    }

    #[Test]
    public function panel_admin_komutu_ayni_epostayi_ikinci_kez_kurmaz(): void
    {
        $this->artisan('panel:admin', ['name' => 'Bir', 'email' => 'ayni@sipario.test'])->assertSuccessful();
        $this->artisan('panel:admin', ['name' => 'İki', 'email' => 'ayni@sipario.test'])
            ->expectsOutputToContain('zaten kayıtlı')
            ->assertFailed();

        $this->assertSame(1, DB::connection('pgsql_panel')->table('admin_users')->count());
    }

    // --- Giriş damgası ------------------------------------------------------------------

    #[Test]
    public function giris_son_giris_damgasini_yazar(): void
    {
        $admin = $this->admin('support', 'destek@sipario.test');
        $this->assertNull($admin->last_login_at);

        Livewire::test(Login::class)
            ->set('email', 'destek@sipario.test')
            ->set('password', 'panel-secret')
            ->call('authenticate')
            ->assertRedirect(route('panel.dashboard'));

        $this->assertNotNull(AdminUser::on('pgsql_panel')->find($admin->id)->last_login_at);
    }
}
