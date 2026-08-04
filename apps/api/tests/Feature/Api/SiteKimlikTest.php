<?php

namespace Tests\Feature\Api;

use App\Abonelik\PlanDeposu;
use App\Livewire\Site\Login;
use App\Livewire\Site\Parola;
use App\Livewire\Site\ParolaYenile;
use App\Livewire\Site\Register;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Livewire\Features\SupportTesting\Testable;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * sipario.com.tr OTURUM YÜZEYİ — giriş, işletme açma, parola sıfırlama/yenileme.
 *
 * Bu dosyanın konusu METİN DEĞİL DAVRANIŞtır: rol kapısı, e-posta normalizasyonu, nötr hatalar,
 * kaba kuvvet sınırı ve firma kodu benzersizliği. Hepsi ekranda görünmeyen ama para/kimlik
 * yüzeyini ayakta tutan kurallar.
 */
class SiteKimlikTest extends ApiTestCase
{
    // ── Giriş ────────────────────────────────────────────────────────────────

    #[Test]
    public function giris_patronu_kabul_eder_ve_hesaba_yonlendirir(): void
    {
        ['patron' => $patron] = $this->makeTenant('giris');

        Livewire::test(Login::class)
            ->set('email', $patron->email)
            ->set('password', 'password')
            ->call('authenticate')
            ->assertHasNoErrors()
            ->assertRedirect(route('site.hesap'));

        $this->assertTrue(Auth::guard('web')->check());
        // Kiracı bağlamı oturuma da yazılır: `auth:web` kullanıcıyı RLS altında ancak bu anahtar
        // sayesinde yükleyebiliyor (ResolveTenantContext'in web oturumu düşüşü).
        $this->assertSame($patron->tenant_id, session('subscription_tenant_id'));
    }

    #[Test]
    public function giris_kurye_ve_operatoru_notr_hatayla_reddeder(): void
    {
        // Kurye ve tezgâh hesapları web'e HİÇ girmez (ekranın alt yazısı bunu söyler). Hata,
        // "bu hesap patron değil" DEMEZ — öyle deseydi geçerli bir e-postayı doğrulardı.
        ['operator' => $operator, 'kurye' => $kurye] = $this->makeTenant('rol');

        foreach ([$operator, $kurye] as $kullanici) {
            Livewire::test(Login::class)
                ->set('email', $kullanici->email)
                ->set('password', 'password')
                ->call('authenticate')
                ->assertHasErrors('email');

            $this->assertFalse(Auth::guard('web')->check());
            $this->app['auth']->forgetGuards();
        }
    }

    #[Test]
    public function giris_epostayi_normalize_eder(): void
    {
        // 2026-08-04 panel arızasının site karşılığı: tarayıcının büyüttüğü ilk harf ve
        // kopyala-yapıştırla kaçan boşluk, DOĞRU parolayla "hatalı" verirdi.
        ['patron' => $patron] = $this->makeTenant('normal');

        Livewire::test(Login::class)
            ->set('email', '  '.mb_strtoupper($patron->email).' ')
            ->set('password', 'password')
            ->call('authenticate')
            ->assertHasNoErrors()
            ->assertRedirect(route('site.hesap'));
    }

    #[Test]
    public function giris_kaba_kuvvet_siniri_bilesenin_icindedir(): void
    {
        // Route throttle'ı Livewire'ı KORUMAZ (eylem /livewire/update'e gider) — sınır burada.
        ['patron' => $patron] = $this->makeTenant('kaba');

        $bilesen = Livewire::test(Login::class)->set('email', $patron->email)->set('password', 'yanlis');

        for ($i = 0; $i < 5; $i++) {
            $bilesen->call('authenticate')->assertHasErrors('email');
        }

        // 6. denemede DOĞRU parola bile geçmez: sınır kimliğe bağlıdır, parolaya değil.
        $bilesen->set('password', 'password')->call('authenticate')->assertHasErrors('email');
        $this->assertFalse(Auth::guard('web')->check());
    }

    #[Test]
    public function giris_suresi_dolmus_bayiyi_reddetmez(): void
    {
        // Faturalama sitesi: süresi dolan bayi TAM DA ödeme yapmak için giriş yapar (API
        // login'den bilinçli fark). Yalnız kullanıcının kendisi pasifse kapı kapanır.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('suresi');
        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)
            ->update(['valid_until' => now()->subDay(), 'status' => 'locked']));

        Livewire::test(Login::class)
            ->set('email', $patron->email)
            ->set('password', 'password')
            ->call('authenticate')
            ->assertHasNoErrors();
    }

    // ── İşletme açma ─────────────────────────────────────────────────────────

    #[Test]
    public function kayit_kvkk_onayi_olmadan_isletme_acmaz(): void
    {
        $this->kayitAdimlari('Merkez Su Bayii', 'yeni@sipario.test', 'merkezbayi')
            ->set('kvkk', false)
            ->call('ileri')
            ->assertHasErrors('kvkk');

        $this->assertSame(0, $this->asOwner(fn () => Tenant::on('pgsql_owner')->count()));
    }

    #[Test]
    public function kayit_secilen_firma_kodunu_uygular(): void
    {
        $this->kayitAdimlari('Merkez Su Bayii', 'kod@sipario.test', 'merkezbayi')
            ->set('kvkk', true)
            ->call('ileri')
            ->assertHasNoErrors()
            ->assertSet('adim', 3)
            ->assertSet('olusanKod', 'merkezbayi');

        // Provisioning kodu addan türetir ("merkez-su-bayii"); kullanıcının seçtiği kod uygulanır.
        $bayi = $this->asOwner(fn () => Tenant::on('pgsql_owner')->firstOrFail());
        $this->assertSame('merkezbayi', $bayi->slug);
        // Yetkilinin adı da yazılır: register() bunu kabul etmiyor, kayıt sonrası düzeltiliyor.
        $this->assertSame('Mehmet Yılmaz', $bayi->contact_name);
    }

    #[Test]
    public function kayit_alinmis_firma_kodunu_reddeder(): void
    {
        ['tenant' => $tenant] = $this->makeTenant('dolu');
        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)->update(['slug' => 'alinmiskod']));

        $this->kayitAdimlari('Başka Su Bayii', 'baska@sipario.test', 'alinmiskod')
            ->set('kvkk', true)
            ->call('ileri')
            ->assertHasErrors('kod');
    }

    #[Test]
    public function kayit_cakisan_epostada_notr_konusur(): void
    {
        // Kullanıcı numaralandırması: mesaj "bu e-posta kayıtlı" DEMEZ.
        ['patron' => $patron] = $this->makeTenant('cakisma');

        $bilesen = $this->kayitAdimlari('İkinci Su Bayii', $patron->email, 'ikincibayi')
            ->set('kvkk', true)
            ->call('ileri')
            ->assertHasErrors('eposta');

        $mesaj = $bilesen->errors()->first('eposta');
        $this->assertStringNotContainsStringIgnoringCase('kayıtlı', $mesaj);
        $this->assertStringNotContainsStringIgnoringCase('kullanılıyor', $mesaj);
    }

    #[Test]
    public function kayit_ekrani_deneme_suresini_plandan_okur(): void
    {
        // Tasarımın "14 gün" metinleri sabit yazılmadı: panelden deneme süresi değişince site
        // sunucuyla yalan söylememeli.
        $gun = (new PlanDeposu('pgsql_owner'))->denemeGun();

        Livewire::test(Register::class)->assertSee($gun.' gün ücretsiz');
        $this->assertSame(30, $gun, 'OKU-BENI kararı: deneme 30 gün.');
    }

    // ── Parola sıfırlama ─────────────────────────────────────────────────────

    #[Test]
    public function parola_sifirlama_kullanici_numaralandirmasi_yapmaz(): void
    {
        ['patron' => $patron] = $this->makeTenant('parola');

        // Kayıtlı adres ve HİÇ OLMAYAN adres AYNI ekranı verir.
        foreach ([$patron->email, 'hicyok@sipario.test'] as $adres) {
            Livewire::test(Parola::class)
                ->set('eposta', $adres)
                ->call('gonder')
                ->assertHasNoErrors()
                ->assertSet('asama', 1)
                ->assertSee('Bağlantıyı gönderdik.');
        }
    }

    #[Test]
    public function parola_sifirlama_gercek_gecerlilik_suresini_yazar(): void
    {
        // Tasarım "30 dakika" diyordu; config 60. Metin config'e uydu, config'e DOKUNULMADI.
        $dakika = (int) config('auth.passwords.users.expire');

        Livewire::test(Parola::class)
            ->set('eposta', 'biri@sipario.test')
            ->call('gonder')
            ->assertSee("Bağlantı {$dakika} dakika geçerli");
    }

    #[Test]
    public function parola_yenileme_gecerli_tokenla_parolayi_degistirir(): void
    {
        ['patron' => $patron] = $this->makeTenant('yenile');
        $token = Provisioning::asOwner(fn () => Password::getRepository()->create($patron));

        Livewire::test(ParolaYenile::class, ['token' => $token, 'email' => $patron->email])
            ->set('parola', 'yeniparola9')
            ->set('parolaTekrar', 'yeniparola9')
            ->call('kaydet')
            ->assertHasNoErrors()
            ->assertSet('bitti', true);

        $taze = $this->asOwner(fn () => User::on('pgsql_owner')->findOrFail($patron->id));
        $this->assertTrue(Hash::check('yeniparola9', $taze->password));

        // Token TEK KULLANIMLIK: aynı bağlantı ikinci kez çalışmaz.
        Livewire::test(ParolaYenile::class, ['token' => $token, 'email' => $patron->email])
            ->set('parola', 'baskaparola9')
            ->set('parolaTekrar', 'baskaparola9')
            ->call('kaydet')
            ->assertHasErrors('parola');
    }

    #[Test]
    public function parola_yenileme_uydurma_tokeni_reddeder(): void
    {
        ['patron' => $patron] = $this->makeTenant('sahte');

        Livewire::test(ParolaYenile::class, ['token' => 'uydurma-token', 'email' => $patron->email])
            ->set('parola', 'yeniparola9')
            ->set('parolaTekrar', 'yeniparola9')
            ->call('kaydet')
            ->assertHasErrors('parola');

        $taze = $this->asOwner(fn () => User::on('pgsql_owner')->findOrFail($patron->id));
        $this->assertTrue(Hash::check('password', $taze->password), 'Parola değişmemeliydi.');
    }

    /**
     * Kayıt akışını GERÇEKTEN yürütür (adım 0 → 1 → 2). `$adim` `#[Locked]`tır ve istemci adım
     * atlayamaz — testin de atlamaması gerekir, yoksa sınadığı yol üretimdeki yol olmaz.
     */
    private function kayitAdimlari(string $isletme, string $eposta, string $kod): Testable
    {
        return Livewire::test(Register::class)
            ->set('isletme', $isletme)
            ->set('eposta', $eposta)
            ->call('ileri')
            ->assertSet('adim', 1)
            ->set('ad', 'Mehmet Yılmaz')
            ->set('parola', 'cokgizli8')
            ->call('ileri')
            ->assertSet('adim', 2)
            ->set('kod', $kod);
    }
}
