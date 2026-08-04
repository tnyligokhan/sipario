<?php

namespace Tests\Feature\Api;

use App\Enums\TenantStatus;
use App\Livewire\Panel\Dashboard;
use App\Livewire\Panel\Login;
use App\Livewire\Panel\TenantList;
use App\Models\AdminUser;
use App\Models\Tenant;
use App\Support\Provisioning;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * PANEL ÇEKİRDEK EKRANLARI (yeni tasarım) — Giriş · Dashboard · Üyeler + navigasyon.
 * Üye detayı ayrı dosyada: `PanelUyeDetayUiTest`.
 *
 * EKRANLARI test eder, servisleri değil (onların kendi testleri var). Sorular: tasarımın METNİ
 * ekrana geldi mi, süzgeçler doğru mu, navigasyon her ekrana ulaşıyor mu.
 */
class PanelCekirdekUiTest extends ApiTestCase
{
    private function admin(string $rol = 'superadmin', string $email = 'cekirdek@sipario.test'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Çekirdek Admin', 'email' => $email, 'password' => 'panel-secret', 'role' => $rol,
        ]));
    }

    // --- Giriş ---------------------------------------------------------------------------

    #[Test]
    public function giris_ekrani_tasarimin_metnini_ve_duzenini_basar(): void
    {
        $this->get('/panel/login')
            ->assertOk()
            ->assertSee('giris-sahne', false)      // kenar çubuksuz sahne (tasarım `05-Giris.jsx`)
            ->assertSee('Yönetim Paneli')
            ->assertSee('Kurucu hesabınla giriş yap.')
            ->assertSee('Giriş Yap')
            ->assertSee('Sipario iç yönetim aracı · yalnızca kurucular');
    }

    #[Test]
    public function giris_ekraninda_kenar_cubugu_yoktur(): void
    {
        // Oturum yokken kenar çubuğu, giriş yapmamış birine panelin haritasını göstermek olurdu.
        $this->get('/panel/login')->assertOk()->assertDontSee('yk-nav', false);
    }

    #[Test]
    public function giris_epostayi_normalize_eder(): void
    {
        // 2026-08-04 arızası: tarayıcının büyüttüğü ilk harf DOĞRU parolayla "Giriş bilgileri
        // hatalı" veriyordu (Postgres: `=` harf duyarlı). Yeniden yazımda kaybolmadı.
        $this->admin('superadmin', 'normalize@sipario.test');

        Livewire::test(Login::class)
            ->set('email', '  Normalize@Sipario.Test ')
            ->set('password', 'panel-secret')
            ->call('authenticate')
            ->assertHasNoErrors()
            ->assertRedirect(route('panel.dashboard'));
    }

    // --- Dashboard -----------------------------------------------------------------------

    #[Test]
    public function dashboard_tasarimin_dort_kartini_ve_iki_listesini_basar(): void
    {
        $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Dashboard::class)
            ->assertOk()
            ->assertSee('Aktif Abone')
            ->assertSee('Deneme Sürümünde')
            ->assertSee('Bu Ay Tahsilat')
            ->assertSee('Bu Ay Net')
            ->assertSee('Denemesi bitmek üzere')
            ->assertSee('Ödemesi geciken');
    }

    #[Test]
    public function dashboard_brief_in_zorunlu_bloklarini_da_basar(): void
    {
        // Tasarımda yok, BRIEF md. 3 istiyor. Biri düşerse panel o soruyu soramaz olur.
        $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Dashboard::class)
            ->assertOk()
            ->assertSee('Bekleyen havale bildirimi')
            ->assertSee('gündür sipariş girmeyen bayiler')
            ->assertSee('Yenileme takvimi')
            ->assertSee('Sipariş girme saatleri');
    }

    #[Test]
    public function dashboard_bos_kurulumda_tasarimin_bos_durum_cumlelerini_gosterir(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Dashboard::class)
            ->assertOk()
            ->assertSee('Bu hafta denemesi biten firma yok.')
            ->assertSee('Geciken ödeme yok. Her şey yolunda.');
    }

    // --- Üyeler --------------------------------------------------------------------------

    #[Test]
    public function uyeler_ekrani_arama_ve_durum_cipleriyle_suzer(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($b['tenant']->id)
            ->update(['status' => TenantStatus::Trial->value]));

        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantList::class)
            ->assertSee($a['tenant']->name)
            ->assertSee($b['tenant']->name)
            ->set('durum', 'trial')
            ->assertSee($b['tenant']->name)
            ->assertDontSee($a['tenant']->name)
            ->set('durum', 'tumu')
            ->set('arama', 'A Su')
            ->assertSee($a['tenant']->name)
            ->assertDontSee($b['tenant']->name);
    }

    #[Test]
    public function uyeler_ekraninda_besinci_durum_cipi_de_vardir(): void
    {
        // Sunucuda 5 durum var, tasarımda 4'tü. `locked` = "Süresi doldu" çipi eklenmezse
        // kilitli bayiler yalnız "Tümü"nde görünürdü ve süzülemezdi.
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantList::class)
            ->assertSee('Süresi doldu')
            ->assertSee('Tümü')
            ->assertSee('Deneme')
            ->assertSee('Aktif')
            ->assertSee('Askıda')
            ->assertSee('İptal');
    }

    #[Test]
    public function uyeler_aramasina_yapistirilan_uzun_rakam_500_vermez(): void
    {
        // 10 haneli telefon bir kez int taşırıp 500 üretmişti; arama artık yalnız metin LIKE'ı.
        $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantList::class)
            ->set('arama', '905321112233445566778899001122')
            ->assertOk()
            ->assertSee('Aramanla eşleşen üye yok.');
    }

    #[Test]
    public function uyeler_aramasinda_joker_karakterler_kacirilir(): void
    {
        // `%` kaçırılmazsa kullanıcı yazdığını değil TÜM listeyi görürdü — sessiz bir yanlış.
        // Kaçış karakteri `!`; ters bölü PDO'nun placeholder tarayıcısını bozup HY093 veriyordu.
        $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(TenantList::class)
            ->set('arama', '%')
            ->assertSee('Aramanla eşleşen üye yok.');
    }

    #[Test]
    public function uyeler_aramasi_kacis_karakterinin_kendisini_de_kacirir(): void
    {
        // `!` kaçış karakteri; kendisi kaçırılmazsa ünlem yazan bayi aramasında aynı sınıftan
        // bir hata doğardı (`!` bir sonraki karakteri sessizce yutar).
        $this->actingAs($this->admin(), 'admin');
        Provisioning::asOwner(fn () => Tenant::factory()->active()->create(['name' => 'Acil! Su']));

        Livewire::test(TenantList::class)
            ->set('arama', 'Acil!')
            ->assertSee('Acil! Su');
    }

    #[Test]
    public function uyeler_aramasi_turkce_harfleri_katlar(): void
    {
        // Bu veritabanı TÜRKÇE harmanlamada: `lower('I')`='ı' ve `lower('İ')`='i'. Katlama
        // `lower()`a bırakılsaydı "İzmir" → "ızmir" olur ve "izmir" araması SIFIR sonuç verirdi.
        $this->actingAs($this->admin(), 'admin');
        Provisioning::asOwner(fn () => Tenant::factory()->active()->create([
            'name' => 'İzmir Su', 'city' => 'İzmir',
        ]));

        foreach (['izmir', 'İZMİR', 'ızmır', 'İzmir'] as $yazim) {
            Livewire::test(TenantList::class)
                ->set('arama', $yazim)
                ->assertSee('İzmir Su')
                ->assertDontSee('Aramanla eşleşen üye yok.');
        }
    }

    #[Test]
    public function uyeler_turkce_harf_sirasina_gore_siralar(): void
    {
        // `localeCompare('tr')` karşılığı: Çınar C'lerin arasına düşer, Z'den sonraya değil.
        $this->actingAs($this->admin(), 'admin');
        foreach (['Zeynep Su', 'Çınar Su', 'Ilgın Su', 'İpek Su'] as $ad) {
            Provisioning::asOwner(fn () => Tenant::factory()->active()->create(['name' => $ad]));
        }

        $govde = Livewire::test(TenantList::class)->html();
        $beklenen = ['Çınar Su', 'Ilgın Su', 'İpek Su', 'Zeynep Su'];
        $sira = array_map(fn ($ad) => strpos($govde, $ad), $beklenen);

        $this->assertNotContains(false, $sira, 'Dört bayinin de listede görünmesi gerekir.');
        $artan = $sira;
        sort($artan);
        $this->assertSame($artan, $sira, 'Türkçe harmanlama uygulanmadı; beklenen sıra: '
            .implode(' < ', $beklenen));
    }

    #[Test]
    public function navigasyon_para_ekranlarina_da_baglanir(): void
    {
        // Nav bağlantıları bu dosyanın sorumluluğunda: görünmezlerse o ekranlara yol kalmaz.
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Dashboard::class)
            ->assertSee(route('panel.payments'), false)
            ->assertSee(route('panel.packages'), false)
            ->assertSee(route('panel.finance'), false)
            ->assertSee(route('panel.notifications'), false)
            ->assertSee(route('panel.audit'), false)
            ->assertSee(route('panel.tenants'), false);
    }

    #[Test]
    public function hesaplar_baglantisi_yalniz_superadmine_gorunur(): void
    {
        $this->actingAs($this->admin('support', 'destek3@sipario.test'), 'admin');
        Livewire::test(Dashboard::class)->assertDontSee(route('panel.admins'), false);

        $this->actingAs($this->admin('superadmin', 'super3@sipario.test'), 'admin');
        Livewire::test(Dashboard::class)->assertSee(route('panel.admins'), false);
    }
}
