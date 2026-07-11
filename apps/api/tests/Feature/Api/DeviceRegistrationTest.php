<?php

namespace Tests\Feature\Api;

use App\Models\Device;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * Cihaz kaydı: istemci üretimli id, idempotentlik, tenant gövdeden alınmaz, doğrulama.
 * Cross-tenant çakışma (409) ve izolasyon TenantIsolationTest'te; burada tek-tenant davranışı.
 */
class DeviceRegistrationTest extends ApiTestCase
{
    #[Test]
    public function yeni_cihaz_201_ve_oturum_tenantina_kaydedilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $deviceId = (string) Str::uuid7();

        $response = $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => $deviceId,
            'platform' => 'android',
            'model' => 'Redmi Note 13',
            'os_version' => 'HyperOS 2',
            'app_version' => '1.0.0',
        ]);

        $response->assertStatus(201);
        $response->assertJsonPath('data.id', $deviceId);

        $device = $this->asOwner(fn () => Device::query()->find($deviceId));
        $this->assertSame($a['tenant']->id, $device->tenant_id);
        $this->assertSame($a['patron']->id, $device->user_id);
    }

    #[Test]
    public function ayni_device_id_ile_tekrar_kayit_idempotent_200_verir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $deviceId = (string) Str::uuid7();

        $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => $deviceId,
            'platform' => 'android',
            'app_version' => '1.0.0',
        ])->assertStatus(201);

        // Aynı id ile ikinci çağrı: yeni satır DEĞİL, güncelleme → 200.
        $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => $deviceId,
            'platform' => 'android',
            'app_version' => '1.1.0',
        ])->assertStatus(200);

        // Tek satır kaldı ve güncellendi.
        $count = $this->asOwner(fn () => Device::query()->where('id', $deviceId)->count());
        $this->assertSame(1, $count);
        $updated = $this->asOwner(fn () => Device::query()->find($deviceId));
        $this->assertSame('1.1.0', $updated->app_version);
    }

    #[Test]
    public function govdedeki_tenant_id_yok_sayilir_oturum_tenanti_kullanilir(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $token = $this->tokenFor($a['patron']);
        $deviceId = (string) Str::uuid7();

        // Kötü niyetle gövdeye B'nin tenant_id'sini koy; sunucu bunu YOK saymalı (RLS + WITH CHECK).
        $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => $deviceId,
            'platform' => 'android',
            'tenant_id' => $b['tenant']->id,
            'user_id' => $b['patron']->id,
        ])->assertSuccessful();

        $device = $this->asOwner(fn () => Device::query()->find($deviceId));
        $this->assertSame($a['tenant']->id, $device->tenant_id, 'Cihaz oturum sahibinin tenant\'ına yazılmalı.');
    }

    #[Test]
    public function index_cihazlari_listeler(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->asToken($token)->getJson('/api/v1/devices')
            ->assertOk()
            ->assertJsonStructure(['data' => [['id', 'platform']]]);
    }

    #[Test]
    public function gecersiz_uuid_ve_eksik_alan_422_verir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // uuid v7 değil (rastgele v4) → 422.
        $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => (string) Str::uuid(),
            'platform' => 'android',
        ])->assertStatus(422);

        // platform eksik → 422.
        $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => (string) Str::uuid7(),
        ])->assertStatus(422);

        // platform android|ios dışında → 422.
        $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => (string) Str::uuid7(),
            'platform' => 'windows',
        ])->assertStatus(422);
    }
}
