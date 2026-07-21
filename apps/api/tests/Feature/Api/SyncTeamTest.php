<?php

namespace Tests\Feature\Api;

use App\Models\User;
use App\Support\Provisioning;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * 4b Dilim 4 — sync yanıtındaki `team` bloğu (K1). Bayinin kullanıcıları mobil önbelleğe iner
 * (atama hedefi + atanan kurye adı çözümü). İki güvence sürekli kanıtlanır:
 *  - PII ASGARİ (kırmızı çizgi #4): yalnız {id,name,role,status} — email/parola/telefon SIZMAZ.
 *  - KİRACI İZOLASYONU (kırmızı çizgi #1): A'nın team'inde B'nin hiçbir kullanıcısı YOK (RLS).
 */
class SyncTeamTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function pull_snapshot_yaniti_team_blogu_tasir_ve_yalniz_asgari_alanlari_verir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $team = $this->asToken($token)->getJson('/api/v1/sync/pull?since=0')->assertOk()->json('team');

        // Bayinin üç kullanıcısı (patron/operator/kurye) — isme göre sıralı.
        $this->assertCount(3, $team);
        $this->assertEqualsCanonicalizing(
            ['patron', 'operator', 'kurye'],
            array_column($team, 'role')
        );

        // PII kanıtı: her eleman TAM OLARAK {id,name,role,status} — başka anahtar yok.
        foreach ($team as $member) {
            $this->assertEqualsCanonicalizing(['id', 'name', 'role', 'status'], array_keys($member));
        }
    }

    #[Test]
    public function push_yaniti_da_team_blogu_tasir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $response = $this->asToken($token)->postJson('/api/v1/sync/push', [
            'events' => [$this->customerUpsert(['name' => 'Ali'])],
        ])->assertOk();

        $this->assertCount(3, $response->json('team'));
        $this->assertNotContains(null, array_column($response->json('team'), 'name'));
    }

    #[Test]
    public function delta_pull_yaniti_da_team_blogu_tasir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // since>0 → delta yolu; değişiklik olmasa da team yayınlanır.
        $team = $this->asToken($token)->getJson('/api/v1/sync/pull?since=1')
            ->assertOk()
            ->assertJsonPath('mode', 'delta')
            ->json('team');

        $this->assertCount(3, $team);
    }

    #[Test]
    public function team_cross_tenant_sizdirmaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);

        $team = $this->asToken($tokenA)->getJson('/api/v1/sync/pull?since=0')->assertOk()->json('team');

        $ids = array_column($team, 'id');
        // A yalnız kendi üç kullanıcısını görür; B'nin hiçbir kullanıcısı sızmaz (RLS).
        $this->assertContains($a['patron']->id, $ids);
        $this->assertContains($a['kurye']->id, $ids);
        foreach ([$b['patron'], $b['operator'], $b['kurye']] as $bUser) {
            $this->assertNotContains($bUser->id, $ids, 'B kullanıcısı A team\'ine sızmamalı.');
        }
    }

    #[Test]
    public function disabled_kullanici_team_de_status_disabled_ile_yer_alir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // Kuryeyi pasifleştir (owner bağlamında — RLS'i meşru atlar).
        Provisioning::asOwner(fn () => User::query()->whereKey($a['kurye']->id)->update(['status' => 'disabled']));

        $team = $this->asToken($token)->getJson('/api/v1/sync/pull?since=0')->assertOk()->json('team');

        $kurye = collect($team)->firstWhere('id', $a['kurye']->id);
        $this->assertNotNull($kurye, 'Pasif kurye ad çözümü için team\'de KALMALI.');
        $this->assertSame('disabled', $kurye['status']);
    }
}
