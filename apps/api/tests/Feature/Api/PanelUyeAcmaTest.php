<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\TenantList;
use App\Mail\Hosgeldiniz;
use App\Models\AdminUser;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Livewire\Features\SupportTesting\Testable;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * PANELDEN ELLE ÜYE AÇMA (BRIEF md. 3 · Üyeler ekranı).
 *
 * `TenantAdminService::createTenant` 5c'den beri vardı ama ARAYÜZÜ YOKTU: satıştaki kişi bayiyi
 * ancak sunucuya girip konsol komutu koşarak açabiliyordu. Buradaki sorular ekranın soruları:
 * form gerçekten bayi + patron yazıyor mu, firma kodu/yetkili/telefon kayboluyor mu, çakışma
 * anlaşılır bir cümleye dönüyor mu ve DESTEK rolü bu kapıdan geçebiliyor mu.
 */
class PanelUyeAcmaTest extends ApiTestCase
{
    private function admin(string $rol = 'superadmin', string $email = 'uye-acan@sipario.test'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Üye Açan', 'email' => $email, 'password' => 'panel-secret', 'role' => $rol,
        ]));
    }

    /** Formu geçerli değerlerle doldurulmuş bir bileşen döndürür. */
    private function form(string $kod = 'aslansu', string $eposta = 'hasan@aslansu.test'): Testable
    {
        return Livewire::test(TenantList::class)
            ->set('uyeForm.isletme', 'Aslan Su Bayii')
            ->set('uyeForm.kod', $kod)
            ->set('uyeForm.yetkili', 'Hasan Aslan')
            ->set('uyeForm.eposta', $eposta)
            ->set('uyeForm.telefon', '0532 111 22 33')
            ->set('uyeForm.parola', 'parola-1234');
    }

    private function bayi(string $kod): ?Tenant
    {
        return Provisioning::asOwner(fn () => Tenant::query()->where('slug', $kod)->first());
    }

    #[Test]
    public function superadmin_panelden_bayi_ve_patronu_tek_seferde_acar(): void
    {
        Mail::fake();
        $admin = $this->admin();
        $this->actingAs($admin, 'admin');

        $this->form()->call('uyeKaydet')->assertHasNoErrors();

        $bayi = $this->bayi('aslansu');
        $this->assertNotNull($bayi, 'Firma kodu formda yazılan olmalı — türetilmiş değil.');
        $this->assertSame('Aslan Su Bayii', $bayi->name);
        $this->assertSame('trial', $bayi->status->value);
        $this->assertTrue($bayi->valid_until?->isFuture(), 'Elle açılan bayi de deneme süresiyle doğar.');

        // Yetkili adı ve telefon KAYBOLMAZ: panelin "Firma, yetkili veya il ara" araması
        // `contact_name` okur; boş kalırsa elle açılan bayi yetkilisiyle aranamaz.
        $this->assertSame('Hasan Aslan', $bayi->contact_name);
        $this->assertSame('0532 111 22 33', $bayi->phone);

        $patron = Provisioning::asOwner(fn () => User::query()->where('tenant_id', $bayi->id)->first());
        $this->assertNotNull($patron);
        $this->assertSame('patron', $patron->username, 'Mobil giriş kullanıcı adı her bayide patron.');
        $this->assertSame('hasan@aslansu.test', $patron->email);
        $this->assertSame('Hasan Aslan', $patron->name);
        $this->assertSame('patron', $patron->role->value);
        $this->assertTrue(Auth::guard('web')->getProvider()->validateCredentials($patron, ['password' => 'parola-1234']));

        // Denetim kaydı düştü ve KVKK-nötr: yalnız eylem + hedef (parola/e-posta yazılmaz).
        $iz = DB::connection('pgsql_panel')->table('panel_audit')
            ->where('action', 'create_tenant')->where('tenant_id', $bayi->id)->first();
        $this->assertNotNull($iz);
        $this->assertSame($admin->id, $iz->admin_user_id);
        $this->assertNull($iz->detail);
    }

    #[Test]
    public function yeni_uye_modali_butun_alanlariyla_cizilir(): void
    {
        // Modal `@include` ile ayrı bir dosyadan gelir ve yalnız `uyeAcik` iken basılır: bu test
        // olmadan o dosyadaki bir Blade hatası HİÇBİR testte görünmez (ekran onsuz da çizilir).
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantList::class)
            ->assertDontSee('Patron parolası')
            ->call('uyeAc')
            ->assertSet('uyeAcik', true)
            ->assertSee('İşletme adı')
            ->assertSee('Firma kodu')
            ->assertSee('Yetkili (ad soyad)')
            ->assertSee('E-posta')
            ->assertSee('Patron parolası')
            ->assertSee('hoş geldiniz e-postası gönder')
            ->assertSee('Üyeyi Aç')
            ->call('uyeKapat')
            ->assertSet('uyeAcik', false)
            ->assertDontSee('Patron parolası');
    }

    #[Test]
    public function acilan_bayinin_kurulum_bilgisi_ekranda_kalir(): void
    {
        // Operatör bu üçünü telefondaki bayiye okuyacak. Modal kapanınca kaybolsalardı, kodu
        // görmek için yeni açılan hesabın parolasını sıfırlamak gerekirdi.
        Mail::fake();
        $this->actingAs($this->admin(), 'admin');

        $this->form()
            ->call('uyeKaydet')
            ->assertSet('uyeAcik', false)
            ->assertSee('aslansu')
            ->assertSee('parola-1234')
            ->assertSee('Aslan Su Bayii');
    }

    #[Test]
    public function isletme_adindan_firma_kodu_onerilir_ama_yazilan_kod_ezilmez(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantList::class)
            ->set('uyeForm.isletme', 'Çınar Su Bayii')
            ->assertSet('uyeForm.kod', 'cinarsubayii')
            ->set('uyeForm.kod', 'CINAR Su!')      // biçime indirilir
            ->assertSet('uyeForm.kod', 'cinarsu')
            ->set('uyeForm.isletme', 'Çınar Su Ticaret')
            ->assertSet('uyeForm.kod', 'cinarsu'); // öneri, dolu alanı EZMEZ
    }

    #[Test]
    public function alinmis_firma_kodu_ve_eposta_anlasilir_cumleye_donusur(): void
    {
        Mail::fake();
        $this->actingAs($this->admin(), 'admin');
        $this->form()->call('uyeKaydet')->assertHasNoErrors();

        // Aynı kod: firma kodu herkese açık bir kimliktir, açıkça söylenir.
        $this->form(kod: 'aslansu', eposta: 'baska@aslansu.test')
            ->call('uyeKaydet')
            ->assertHasErrors('uyeForm.kod');

        // Aynı e-posta: `users.email` global tekil.
        $this->form(kod: 'baskakod', eposta: 'hasan@aslansu.test')
            ->call('uyeKaydet')
            ->assertHasErrors('uyeForm.eposta');

        $this->assertSame(1, Provisioning::asOwner(fn () => Tenant::query()->count()),
            'Reddedilen deneme yarım bir bayi bırakmamalı.');
    }

    #[Test]
    public function bozuk_firma_kodu_ve_kisa_parola_formda_durur(): void
    {
        // Kod kuralı DB CHECK'inin (`tenants_slug_check`) aynısı; formda durmayan bir kod
        // Postgres'te 23514 olur ve operatör anlamsız bir 500 görür.
        $this->actingAs($this->admin(), 'admin');

        $this->form(kod: 'ab')->call('uyeKaydet')->assertHasErrors('uyeForm.kod');
        $this->form()->set('uyeForm.parola', 'kisa')->call('uyeKaydet')->assertHasErrors('uyeForm.parola');
        $this->form()->set('uyeForm.eposta', 'nokta-yok')->call('uyeKaydet')->assertHasErrors('uyeForm.eposta');

        $this->assertSame(0, Provisioning::asOwner(fn () => Tenant::query()->count()));
    }

    #[Test]
    public function eposta_ve_kod_buyuk_harfle_yazilsa_da_kucuk_harfe_iner(): void
    {
        // `unique` kuralı Postgres'te harfe duyarlıdır ve e-posta DB'de küçük harfle yaşar:
        // normalize edilmezse ön kontrol "boşta" der, INSERT 23505 ile düşerdi.
        Mail::fake();
        $this->actingAs($this->admin(), 'admin');

        $this->form()->set('uyeForm.eposta', '  Hasan@Aslansu.TEST ')->call('uyeKaydet')->assertHasNoErrors();

        $this->assertSame('hasan@aslansu.test', Provisioning::asOwner(
            fn () => User::query()->where('tenant_id', $this->bayi('aslansu')->id)->value('email')
        ));

        $this->form(kod: 'ikinci', eposta: 'HASAN@ASLANSU.TEST')
            ->call('uyeKaydet')
            ->assertHasErrors('uyeForm.eposta');
    }

    #[Test]
    public function hos_geldiniz_epostasi_isaretliyse_gider_isaretsizse_gitmez(): void
    {
        $this->actingAs($this->admin(), 'admin');

        // `SiparioPostasi` ShouldQueue'dur: posta KUYRUĞA girer, doğrudan gönderilmez —
        // `assertSent` burada her zaman boş döner ve testi sahte kırmızı yapar.
        Mail::fake();
        $this->form()->call('uyeKaydet')->assertHasNoErrors();
        Mail::assertQueued(Hosgeldiniz::class, fn (Hosgeldiniz $m) => $m->firmaKodu === 'aslansu'
            && $m->kullaniciAdi === 'patron'
            && $m->hasTo('hasan@aslansu.test'));

        Mail::fake();
        $this->form(kod: 'ikincisi', eposta: 'ikinci@aslansu.test')
            ->set('uyeForm.posta', false)
            ->call('uyeKaydet')
            ->assertHasNoErrors();
        Mail::assertNothingOutgoing();

        // Posta gitmese de bayi açılır: e-posta bir yan etkidir, hesabın şartı değil.
        $this->assertNotNull($this->bayi('ikincisi'));
    }

    #[Test]
    public function destek_rolu_uye_acamaz_ve_denemesi_denetime_dusar(): void
    {
        // Düğmenin gizlenmesi yetki denetimi değildir: bileşen meşru açıldıktan SONRA rol düşse
        // bile eylem kapısı her istekte tekrarlanmalı (AdminUsers ekranındaki desenin aynısı).
        $super = $this->admin();
        $destek = $this->admin('support', 'uye-destek@sipario.test');

        foreach (['uyeAc', 'uyeKaydet'] as $eylem) {
            $this->actingAs($super, 'admin');
            $bilesen = $this->form()->assertOk();

            Auth::guard('admin')->setUser($destek);
            $bilesen->call($eylem)->assertForbidden();
        }

        $this->assertSame(0, Provisioning::asOwner(fn () => Tenant::query()->count()), 'Destek rolü bayi açamamalı.');
        $this->assertSame(2, DB::connection('pgsql_panel')->table('panel_audit')
            ->where('action', 'create_tenant_denied')->where('detail', 'yetkisiz')->count());
    }

    #[Test]
    public function destek_rolu_yeni_uye_dugmesini_gormez(): void
    {
        $this->actingAs($this->admin('support', 'uye-destek2@sipario.test'), 'admin');

        Livewire::test(TenantList::class)->assertOk()->assertDontSee('Yeni Üye');

        $this->actingAs($this->admin(), 'admin');
        Livewire::test(TenantList::class)->assertOk()->assertSee('Yeni Üye');
    }
}
