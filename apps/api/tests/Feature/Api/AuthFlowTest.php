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
 */
class AuthFlowTest extends ApiTestCase
{
    #[Test]
    public function gecerli_bilgiyle_giris_token_user_tenant_ve_server_time_doner(): void
    {
        $a = $this->makeTenant('a');

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => $a['patron']->email,
            'password' => 'password',
        ]);

        $response->assertOk();
        $response->assertJsonStructure(['token', 'user' => ['id', 'email', 'role'], 'tenant' => ['id'], 'server_time']);
        $response->assertJsonPath('tenant.id', $a['tenant']->id);
        $response->assertJsonPath('user.id', $a['patron']->id);
        $this->assertNotEmpty($response->json('token'));

        // Parola yanıtta sızmaz.
        $this->assertStringNotContainsString('password', strtolower($response->json('user.email') ?? ''));
        $this->assertArrayNotHasKey('password', $response->json('user'));
    }

    #[Test]
    public function alinan_token_korumali_endpointe_erisir(): void
    {
        $a = $this->makeTenant('a');

        $token = $this->postJson('/api/v1/auth/login', [
            'email' => $a['patron']->email,
            'password' => 'password',
        ])->json('token');

        $this->asToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('user.id', $a['patron']->id);
    }

    #[Test]
    public function yanlis_parola_ve_olmayan_email_ayni_notr_401i_verir(): void
    {
        $a = $this->makeTenant('a');

        $wrongPassword = $this->postJson('/api/v1/auth/login', [
            'email' => $a['patron']->email,
            'password' => 'yanlis-parola',
        ]);
        $noSuchUser = $this->postJson('/api/v1/auth/login', [
            'email' => 'hic-yok@sipario.test',
            'password' => 'yanlis-parola',
        ]);

        $wrongPassword->assertStatus(401);
        $noSuchUser->assertStatus(401);
        // Numaralandırma önleme: iki durum AYNI mesajı döner (email var/yok ayrımı sızmaz).
        $this->assertSame($wrongPassword->json('message'), $noSuchUser->json('message'));
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
            ]);

            return compact('tenant', 'patron');
        });

        $this->postJson('/api/v1/auth/login', [
            'email' => $locked['patron']->email,
            'password' => 'password',
        ])->assertStatus(403);
    }

    #[Test]
    public function pasif_kullanici_girisi_403_verir(): void
    {
        $disabled = Provisioning::asOwner(function () {
            $tenant = Tenant::factory()->active()->create(['name' => 'Aktif Bayi']);
            $user = User::factory()->patron()->disabled()->create([
                'tenant_id' => $tenant->id,
                'email' => 'pasif-patron@sipario.test',
            ]);

            return compact('tenant', 'user');
        });

        $this->postJson('/api/v1/auth/login', [
            'email' => $disabled['user']->email,
            'password' => 'password',
        ])->assertStatus(403);
    }

    #[Test]
    public function eksik_alan_ve_gecersiz_email_422_verir(): void
    {
        $this->postJson('/api/v1/auth/login', [])->assertStatus(422);
        $this->postJson('/api/v1/auth/login', [
            'email' => 'gecersiz-email',
            'password' => 'password',
        ])->assertStatus(422);
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
        $token = $this->postJson('/api/v1/auth/login', [
            'email' => $a['patron']->email,
            'password' => 'password',
        ])->json('token');

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

        $this->postJson('/api/v1/auth/login', [
            'email' => $a['patron']->email,
            'password' => 'password',
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
    public function hata_yanitlarinda_da_server_time_bulunur(): void
    {
        // AppendServerTime tüm JSON yanıtlara ekler; 401 gövdesinde de olmalı (istemci offset'i).
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'hic-yok@sipario.test',
            'password' => 'x',
        ]);
        $response->assertStatus(401);
        $this->assertArrayHasKey('server_time', $response->json());
    }
}
