<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * EKİP KİMLİK BİLGİLERİ — `PATCH /team/{user}/credentials` (kullanıcı isteği 2026-08-04).
 *
 * Kiracı izolasyonu ayrı bir yerde kanıtlanır (TenantIsolationTest — kırmızı çizgi #1 matrisi).
 * Burada uç noktanın KENDİ sözleşmesi çivilenir: kim değiştirebilir, kimi değiştirebilir,
 * parola değişince ne olur, ve değiştirilen kimlikle GERÇEKTEN giriş yapılabiliyor mu.
 */
class TeamCredentialsTest extends ApiTestCase
{
    #[Test]
    public function patron_kuryenin_kullanici_adini_ve_parolasini_degistirir(): void
    {
        $a = $this->makeTenant('a');

        $this->asToken($this->tokenFor($a['patron']))
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", [
                'username' => 'yeni.kurye',
                'password' => 'kurye1234',
            ])
            ->assertOk()
            ->assertJsonPath('sessions_revoked', true);

        $kurye = $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id));
        $this->assertSame('yeni.kurye', $kurye->username);
        $this->assertTrue(Hash::check('kurye1234', $kurye->password), 'Parola hash olarak yazılmalı.');

        // ASIL KANIT: yeni kimlikle giriş çalışıyor. Alanları yazmak yetmez — giriş sorgusu
        // (`sipario_login_lookup`) kullanıcı adını `lower()` ile arar ve parolayı hash'e karşı
        // doğrular; ikisinden biri ayrışsaydı kurye sahada kapıda kalırdı.
        $this->postJson('/api/v1/auth/login', [
            'tenant_code' => $a['tenant']->slug,
            'username' => 'yeni.kurye',
            'password' => 'kurye1234',
        ])->assertOk();
    }

    #[Test]
    public function parola_degisince_kuryenin_acik_oturumlari_duser(): void
    {
        // Özelliğin varlık sebebinin yarısı budur: patron parolayı çoğu zaman işten ayrılan ya da
        // telefonunu kaybeden kurye için değiştirir. Eski token yaşamaya devam etseydi değişiklik
        // HİÇBİR ŞEY yapmamış olurdu.
        $a = $this->makeTenant('a');
        $kuryeToken = $this->tokenFor($a['kurye']);

        $this->asToken($kuryeToken)->getJson('/api/v1/auth/me')->assertOk();

        $this->asToken($this->tokenFor($a['patron']))
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", ['password' => 'baska1234'])
            ->assertOk();

        $this->asToken($kuryeToken)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    #[Test]
    public function yalniz_kullanici_adi_degisince_oturum_dusmez(): void
    {
        // Sahadaki kuryeyi, patron bir yazım hatası düzelttiği için işinden etmek gereksiz bir
        // bedeldir: token kullanıcı KİMLİĞİNE bağlıdır, adına değil.
        $a = $this->makeTenant('a');
        $kuryeToken = $this->tokenFor($a['kurye']);

        $this->asToken($this->tokenFor($a['patron']))
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", ['username' => 'duzeltilmis'])
            ->assertOk()
            ->assertJsonPath('sessions_revoked', false);

        $this->asToken($kuryeToken)->getJson('/api/v1/auth/me')->assertOk();
    }

    #[Test]
    public function kurye_kimseninkini_degistiremez(): void
    {
        // Route `role:patron` ile korunur. Kurye kendi parolasını da buradan değiştiremez —
        // kimlik değişimi bir YÖNETİM işlemidir; kendi parolasını değiştirebilseydi patron
        // erişimi kaybederdi (ve kurtarma yolu yalnız bizde olurdu).
        $a = $this->makeTenant('a');

        $this->asToken($this->tokenFor($a['kurye']))
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", ['password' => 'kendi1234'])
            ->assertForbidden();
    }

    #[Test]
    public function patron_hesabinin_kimligi_bu_uctan_degistirilemez(): void
    {
        // İki taraflı gerekçe: (1) başka bir patronun kimliğini ele geçirme yüzeyi doğmasın;
        // (2) patron kendi kullanıcı adını buradan yanlış yazarsa kendini uygulamadan kilitler.
        $a = $this->makeTenant('a');

        $this->asToken($this->tokenFor($a['patron']))
            ->patchJson("/api/v1/team/{$a['patron']->id}/credentials", ['password' => 'patron1234'])
            ->assertForbidden();
    }

    #[Test]
    public function ayni_bayide_kullanilan_kullanici_adi_reddedilir(): void
    {
        $a = $this->makeTenant('a');
        $mevcut = $this->asOwner(fn () => User::query()->findOrFail($a['operator']->id)->username);

        $this->asToken($this->tokenFor($a['patron']))
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", ['username' => $mevcut])
            ->assertStatus(422)
            ->assertJsonValidationErrors('username');
    }

    #[Test]
    public function gecersiz_kullanici_adi_ve_kisa_parola_form_hatasi_verir(): void
    {
        // Kural veritabanındaki CHECK ile aynıdır; kapı burada olmasaydı kullanıcı 500 görürdü.
        $a = $this->makeTenant('a');
        $patron = $this->tokenFor($a['patron']);

        $this->asToken($patron)
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", ['username' => 'ab'])
            ->assertStatus(422)->assertJsonValidationErrors('username');

        $this->asToken($patron)
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", ['username' => 'boşluk var'])
            ->assertStatus(422)->assertJsonValidationErrors('username');

        $this->asToken($patron)
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", ['password' => '123'])
            ->assertStatus(422)->assertJsonValidationErrors('password');

        // Boş gövde de hatadır: "hiçbir şey gönderme" bir güncelleme değildir.
        $this->asToken($patron)
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", [])
            ->assertStatus(422);
    }

    #[Test]
    public function buyuk_harfli_kullanici_adi_kucultulerek_kabul_edilir(): void
    {
        // Giriş sorgusu `lower()` ile arar. Patron "Mehmet" yazdığında reddetmek yerine sessizce
        // indirmek doğru davranıştır — niyet açıktır ve aksi hâlde kurye giremezdi.
        $a = $this->makeTenant('a');

        $this->asToken($this->tokenFor($a['patron']))
            ->patchJson("/api/v1/team/{$a['kurye']->id}/credentials", ['username' => 'Mehmet.Usta'])
            ->assertOk();

        $this->assertSame(
            'mehmet.usta',
            $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id)->username)
        );
    }

    #[Test]
    public function team_blogu_kullanici_adini_tasir_ama_parolayi_asla(): void
    {
        // Kuryeler ekranı giriş adını gösterebilmeli; parola hiçbir yönde OKUNMAZ.
        $a = $this->makeTenant('a');

        $team = $this->asToken($this->tokenFor($a['patron']))
            ->getJson('/api/v1/sync/pull?since=0')->assertOk()->json('team');

        foreach ($team as $uye) {
            $this->assertArrayHasKey('username', $uye);
            $this->assertNotSame('', $uye['username']);
            $this->assertArrayNotHasKey('password', $uye);
        }
    }
}
