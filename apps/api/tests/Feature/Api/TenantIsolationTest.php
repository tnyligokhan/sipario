<?php

namespace Tests\Feature\Api;

use App\Models\Device;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * KIRMIZI ÇİZGİ #1 — bir bayi başka bayinin verisini ASLA göremez/değiştiremez.
 *
 * Matris: her tenant-scope endpoint için "B'nin kaydını A'nın token'ıyla iste" senaryosu.
 *  - Okuma (show):   B'nin id'si A token'ıyla → 404 (RLS satırı gizler, model binding düşer).
 *  - Liste (index):  A yalnız kendi kayıtlarını görür; B'nin hiçbir kaydı sızmaz.
 *  - Yazma (store):  A, B'nin device_id'sini gönderirse B'nin satırı ne görünür ne değişir → 409.
 *
 * Not (Faz 1 kapsamı): devices kaynağında ayrı PUT/DELETE route'u YOKTUR; yazma yolu idempotent
 * POST /devices'tır (updateOrCreate). Cross-tenant yazma izolasyonu bu yüzden store→409 + "B'nin
 * satırı değişmedi" doğrulamasıyla kanıtlanır. Yeni tenant-scope endpoint eklendiğinde bu matrise
 * satır eklenmelidir; RouteCoverageGuardTest testsiz eklemeyi build'de kırar.
 */
class TenantIsolationTest extends ApiTestCase
{
    #[Test]
    public function devices_show_baska_bayinin_kaydini_404_verir(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);

        // B'nin cihazının GERÇEK, geçerli id'si — ama A'nın bağlamında RLS onu gizler.
        $response = $this->asToken($tokenA)->getJson("/api/v1/devices/{$b['device']->id}");

        $response->assertNotFound();
    }

    #[Test]
    public function devices_index_yalnizca_kendi_bayinin_cihazlarini_dondurur(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);

        $response = $this->asToken($tokenA)->getJson('/api/v1/devices');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->all();

        // A yalnız kendi cihazını görür; B'nin cihaz id'si listede ASLA yer almaz.
        $this->assertContains($a['device']->id, $ids);
        $this->assertNotContains($b['device']->id, $ids);
        $this->assertCount(1, $ids, 'A yalnız kendi tek cihazını görmeli.');
    }

    #[Test]
    public function devices_store_baska_bayinin_device_idsini_409_verir_ve_o_satiri_degistirmez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);

        $bDeviceId = $b['device']->id;
        $bOriginalTenant = $b['device']->tenant_id;

        // A, B'ye ait mevcut device_id ile kayıt denemesi yapar.
        $response = $this->asToken($tokenA)->postJson('/api/v1/devices', [
            'device_id' => $bDeviceId,
            'platform' => 'android',
            'model' => 'A-nin-ele-gecirme-denemesi',
        ]);

        $response->assertStatus(409);

        // B'nin cihaz satırı ne A'ya geçti ne de modeli değişti (owner ile doğrula).
        $fresh = $this->asOwner(fn () => Device::query()->find($bDeviceId));
        $this->assertNotNull($fresh);
        $this->assertSame($bOriginalTenant, $fresh->tenant_id, 'B cihazının tenant_id\'si değişmemeli.');
        $this->assertNotSame('A-nin-ele-gecirme-denemesi', $fresh->model, 'B cihazının modeli ezilmemeli.');
    }

    #[Test]
    public function auth_me_yalnizca_kendi_tenant_baglamini_dondurur(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);

        $response = $this->asToken($tokenA)->getJson('/api/v1/auth/me');

        $response->assertOk();
        $response->assertJsonPath('tenant.id', $a['tenant']->id);
        $response->assertJsonPath('user.id', $a['patron']->id);
        // B'nin tenant/kullanıcı kimliği yanıtta hiçbir yerde geçmez.
        $this->assertStringNotContainsString($b['tenant']->id, $response->getContent());
        $this->assertStringNotContainsString($b['patron']->id, $response->getContent());
    }

    #[Test]
    public function bir_bayinin_tokeni_diger_bayinin_var_olmayan_cihaz_idsiyle_de_404_verir(): void
    {
        // Rastgele (hiç var olmayan) bir uuid de 404 vermeli — enumeration/kaçak yok.
        $a = $this->makeTenant('a');
        $tokenA = $this->tokenFor($a['patron']);

        $response = $this->asToken($tokenA)->getJson('/api/v1/devices/'.Str::uuid7());

        $response->assertNotFound();
    }

    #[Test]
    public function token_olmadan_korumali_endpointler_401_verir(): void
    {
        // Bağlam kurulamaz → RLS sıfır satır → auth:sanctum 401. (Güvenli varsayılanın uçtan ucu.)
        $this->getJson('/api/v1/devices')->assertUnauthorized();
        $this->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->postJson('/api/v1/devices', [
            'device_id' => (string) Str::uuid7(),
            'platform' => 'android',
        ])->assertUnauthorized();
    }
}
