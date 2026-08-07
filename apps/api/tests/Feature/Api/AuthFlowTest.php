<?php

namespace Tests\Feature\Api;

use App\Enums\TenantStatus;
use App\Models\Device;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * Auth akışı: giriş, token üretimi, nötr hata (kullanıcı numaralandırma yok), hesap/bayi durumu
 * kapıları, token iptali, server_time. Parola tüm seed kullanıcılarda 'password' (UserFactory).
 *
 * GİRİŞ SÖZLEŞMESİ (tasarım `s-giris.jsx`): firma kodu + kullanıcı adı + parola.
 * E-posta ile giriş KALDIRILDI; bu dosyadaki `eposta_ile_giris_artik_kabul_edilmez` testi
 * eski yüzeyin geri sızmadığını sabitler.
 */
class AuthFlowTest extends ApiTestCase
{
    #[Test]
    public function gecerli_bilgiyle_giris_token_user_tenant_ve_server_time_doner(): void
    {
        $a = $this->makeTenant('a');

        $response = $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesi($a['tenant'], $a['patron'])
        );

        $response->assertOk();
        $response->assertJsonStructure([
            'token',
            'user' => ['id', 'email', 'username', 'role'],
            'tenant' => ['id'],
            'server_time',
        ]);
        $response->assertJsonPath('tenant.id', $a['tenant']->id);
        $response->assertJsonPath('user.id', $a['patron']->id);
        $response->assertJsonPath('user.username', 'patron');
        $this->assertNotEmpty($response->json('token'));

        // Parola yanıtta sızmaz.
        $this->assertArrayNotHasKey('password', $response->json('user'));
    }

    #[Test]
    public function ayni_kullanici_adi_farkli_firmalarda_kendi_hesabini_acar(): void
    {
        // Kullanıcı adı TENANT İÇİNDE tekildir: iki bayide de "patron" vardır ve firma kodu
        // hangisinin girdiğini belirler. Bu, e-postadan kullanıcı adına geçişin ana gerekçesi.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $this->postJson('/api/v1/auth/login', $this->girisGovdesi($a['tenant'], $a['patron']))
            ->assertOk()
            ->assertJsonPath('user.id', $a['patron']->id);

        $this->postJson('/api/v1/auth/login', $this->girisGovdesi($b['tenant'], $b['patron']))
            ->assertOk()
            ->assertJsonPath('user.id', $b['patron']->id);
    }

    #[Test]
    public function baska_firmanin_koduyla_giris_401_verir(): void
    {
        // Firma kodu + kullanıcı adı ÇİFTİ aranır: doğru parola bile olsa çapraz eşleşme yok.
        //
        // DİKKAT — bu test yalnız A'ya ÖZGÜ bir kullanıcı adıyla anlamlıdır. makeTenant her
        // bayiye aynı 'patron' adını verdiği için o adla denemek B'nin kendi patronunu bulur
        // ve 200 döner; sınanan şey çapraz sızıntı olmaz. Bu yüzden A'ya tekil bir ad açıyoruz.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $ozelKullanici = Provisioning::asOwner(fn () => User::factory()->operator()->create([
            'tenant_id' => $a['tenant']->id,
            'name' => 'A Yalnizca',
            'email' => 'a-yalnizca@sipario.test',
            'username' => 'a.yalnizca',
        ]));

        // Kendi firmasında girer…
        $this->postJson('/api/v1/auth/login', [
            'tenant_code' => $a['tenant']->slug,
            'username' => $ozelKullanici->username,
            'password' => 'password',
        ])->assertOk();

        // …ama B'nin firma koduyla aynı kullanıcı adı+parola 401.
        $this->postJson('/api/v1/auth/login', [
            'tenant_code' => $b['tenant']->slug,
            'username' => $ozelKullanici->username,
            'password' => 'password',
        ])->assertStatus(401);
    }

    #[Test]
    public function eposta_ile_giris_artik_kabul_edilmez(): void
    {
        // Eski yüzey geri sızarsa burada yakalanır: e-posta alanı artık tanınmaz ve
        // zorunlu alanlar eksik olduğu için 422 döner (sessizce çalışmaz).
        $a = $this->makeTenant('a');

        $this->postJson('/api/v1/auth/login', [
            'email' => $a['patron']->email,
            'password' => 'password',
        ])->assertStatus(422);
    }

    #[Test]
    public function alinan_token_korumali_endpointe_erisir(): void
    {
        $a = $this->makeTenant('a');

        $token = $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesi($a['tenant'], $a['patron'])
        )->json('token');

        $this->asToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('user.id', $a['patron']->id);
    }

    #[Test]
    public function yanlis_parola_olmayan_kullanici_ve_olmayan_firma_ayni_notr_401i_verir(): void
    {
        $a = $this->makeTenant('a');

        $yanlisParola = $this->postJson('/api/v1/auth/login', [
            'tenant_code' => $a['tenant']->slug,
            'username' => $a['patron']->username,
            'password' => 'yanlis-parola',
        ]);
        $olmayanKullanici = $this->postJson('/api/v1/auth/login', [
            'tenant_code' => $a['tenant']->slug,
            'username' => 'hic.yok',
            'password' => 'yanlis-parola',
        ]);
        $olmayanFirma = $this->postJson('/api/v1/auth/login', [
            'tenant_code' => 'hic-olmayan-firma',
            'username' => $a['patron']->username,
            'password' => 'yanlis-parola',
        ]);

        $yanlisParola->assertStatus(401);
        $olmayanKullanici->assertStatus(401);
        $olmayanFirma->assertStatus(401);

        // Numaralandırma önleme: ÜÇ durum da AYNI mesajı döner — hangi alanın yanlış olduğu
        // sızsaydı geçerli firma kodları ve kullanıcı adları tek tek taranabilirdi.
        $this->assertSame($yanlisParola->json('message'), $olmayanKullanici->json('message'));
        $this->assertSame($yanlisParola->json('message'), $olmayanFirma->json('message'));
    }

    #[Test]
    public function kilitli_bayi_girisi_notr_403_verir(): void
    {
        // status=locked bayi + patron; login trial/active dışına izin vermez.
        $locked = Provisioning::asOwner(function () {
            $tenant = Tenant::factory()->create([
                'name' => 'Kilitli Bayi',
                'status' => TenantStatus::Locked->value,
                'valid_until' => now()->subDay(),
            ]);
            $patron = User::factory()->patron()->create([
                'tenant_id' => $tenant->id,
                'email' => 'kilitli-patron@sipario.test',
                'username' => 'patron',
            ]);

            return compact('tenant', 'patron');
        });

        $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesi($locked['tenant'], $locked['patron'])
        )->assertStatus(403);
    }

    #[Test]
    public function pasif_kullanici_girisi_403_verir(): void
    {
        $disabled = Provisioning::asOwner(function () {
            $tenant = Tenant::factory()->active()->create(['name' => 'Aktif Bayi']);
            $user = User::factory()->patron()->disabled()->create([
                'tenant_id' => $tenant->id,
                'email' => 'pasif-patron@sipario.test',
                'username' => 'patron',
            ]);

            return compact('tenant', 'user');
        });

        $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesi($disabled['tenant'], $disabled['user'])
        )->assertStatus(403);
    }

    #[Test]
    public function eksik_alan_ve_bicimsiz_kimlik_422_verir(): void
    {
        $a = $this->makeTenant('a');

        $this->postJson('/api/v1/auth/login', [])->assertStatus(422);

        // Tasarımın kendi doğrulamaları: firma kodu ^[a-z0-9-]{3,}$, kullanıcı adı
        // ^[a-z0-9._-]{3,}$, parola >= 4. Üçü de sunucuda ayrıca sınanır.
        $this->postJson('/api/v1/auth/login', [
            'tenant_code' => 'ab',            // 3 haneden kısa
            'username' => 'patron',
            'password' => 'password',
        ])->assertStatus(422);

        $this->postJson('/api/v1/auth/login', [
            'tenant_code' => $a['tenant']->slug,
            'username' => 'ku@llanici',       // '@' kullanıcı adında geçersiz
            'password' => 'password',
        ])->assertStatus(422);

        $this->postJson('/api/v1/auth/login', [
            'tenant_code' => $a['tenant']->slug,
            'username' => 'patron',
            'password' => 'abc',              // 4 karakterden kısa
        ])->assertStatus(422);
    }

    #[Test]
    public function buyuk_harfli_firma_kodu_ve_kullanici_adi_kabul_edilir(): void
    {
        // Klavye büyük harfe kaçarsa giriş engellenmemeli — sunucu küçük harfe normalize eder.
        $a = $this->makeTenant('a');

        $this->postJson('/api/v1/auth/login', [
            'tenant_code' => strtoupper($a['tenant']->slug),
            'username' => 'PATRON',
            'password' => 'password',
        ])->assertOk()->assertJsonPath('user.id', $a['patron']->id);
    }

    #[Test]
    public function korumali_endpoint_tokensiz_401_verir(): void
    {
        $this->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    #[Test]
    public function logout_tokeni_iptal_eder_ve_sonrasinda_401_doner(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesi($a['tenant'], $a['patron'])
        )->json('token');

        // Logout 204 döner (gövdesiz).
        $this->asToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();

        // İptal edilen token artık geçersiz.
        $this->asToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    #[Test]
    public function login_sirasinda_device_blogu_cihazi_kullanicinin_tenantina_kaydeder(): void
    {
        $a = $this->makeTenant('a');
        $deviceId = (string) Str::uuid7();

        $this->postJson('/api/v1/auth/login', $this->girisGovdesi($a['tenant'], $a['patron']) + [
            'device' => [
                'device_id' => $deviceId,
                'platform' => 'android',
                'model' => 'Xiaomi 14',
            ],
        ])->assertOk();

        // Cihaz owner ile doğrulanır: A'nın tenant'ına yazıldı.
        $device = $this->asOwner(fn () => Device::query()->find($deviceId));
        $this->assertNotNull($device);
        $this->assertSame($a['tenant']->id, $device->tenant_id);
        $this->assertSame($a['patron']->id, $device->user_id);
    }

    #[Test]
    public function baska_bayiye_kayitli_device_id_girisi_dusurmez(): void
    {
        // SAHA HATASI 2026-07-29: `device_id` istemcide üretilir ve kurulum boyunca KALICIDIR.
        // Aynı telefon başka bir bayiye giriş yapınca o kimlik başka kiracının satırında durur;
        // `updateOrCreate` önce SELECT atar, RLS satırı GİZLER, "yok" sanıp INSERT'e geçer ve
        // birincil anahtar çakışır. Kullanıcı DOĞRU parolayı girdiği hâlde ham bir SQL hatası
        // görüyordu — oysa kimlik doğrulama başarılıydı.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $deviceId = (string) Str::uuid7();

        // Telefon önce A bayisine giriş yapar — cihaz A'ya yazılır.
        $this->postJson('/api/v1/auth/login', $this->girisGovdesi($a['tenant'], $a['patron']) + [
            'device' => ['device_id' => $deviceId, 'platform' => 'android'],
        ])->assertOk();

        // AYNI telefon şimdi B bayisine giriş yapıyor.
        $yanit = $this->postJson('/api/v1/auth/login', $this->girisGovdesi($b['tenant'], $b['patron']) + [
            'device' => ['device_id' => $deviceId, 'platform' => 'android'],
        ]);

        // Giriş BAŞARILI olmalı: cihaz bloğu opsiyonel bir yan etkidir, kimlik doğrulama değil.
        $yanit->assertOk();
        $this->assertNotEmpty($yanit->json('token'));

        // A'nın cihaz kaydına DOKUNULMAZ — sahibini değiştirmek, o bayinin bildirim
        // kaydını sessizce çalmak olurdu (DeviceController::store ile aynı politika).
        $device = $this->asOwner(fn () => Device::query()->find($deviceId));
        $this->assertSame($a['tenant']->id, $device->tenant_id);
    }

    #[Test]
    public function hata_yanitlarinda_da_server_time_bulunur(): void
    {
        // AppendServerTime tüm JSON yanıtlara ekler; 401 gövdesinde de olmalı (istemci offset'i).
        $response = $this->postJson('/api/v1/auth/login', [
            'tenant_code' => 'hic-olmayan-firma',
            'username' => 'hic.yok',
            'password' => 'xxxx',
        ]);
        $response->assertStatus(401);
        $this->assertArrayHasKey('server_time', $response->json());
    }
}
