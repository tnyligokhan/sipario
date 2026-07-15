<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\Tenant;
use App\Support\Provisioning;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5a — abonelik kilidi + durum yayını (SUNUCU enforcement, DECISIONS "Faz 5 — mimari").
 *
 * Kilit YALNIZ sync/push'ta (tek yazma yüzeyi); okuma/pull ASLA kilitlenmez (kırmızı çizgi #5).
 * Kilitliyken occurred_at <= locked_at olan (offline birikmiş) yazım KABUL, occurred_at > locked_at
 * olan 'locked' reddedilir (geçici; yenilenince retry uygulanır → processed_events'e yazılmaz).
 * valid_until NULL → kilitsiz. Gerçek Postgres 16 + RLS'e koşar.
 */
class SubscriptionLockTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /**
     * Owner (RLS-atlayan superuser) ile tenant kilit alanlarını ayarla (panel/süre-dolumu simülasyonu).
     *
     * @param  array<string, mixed>  $attrs
     */
    private function setTenant(string $tenantId, array $attrs): void
    {
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($tenantId)->update($attrs));
    }

    #[Test]
    public function abonelik_gecerliyken_push_normal_uygulanir_ve_subscription_yayinlanir(): void
    {
        $a = $this->makeTenant('a'); // factory active(): valid_until = now+1yıl (gelecek → kilitsiz)
        $token = $this->tokenFor($a['patron']);

        $response = $this->pushEvents($token, [$this->customerUpsert(['name' => 'Geçerli Abone'])]);

        $response->assertOk();
        $response->assertJsonPath('results.0.status', 'applied');
        $response->assertJsonPath('subscription.status', 'active');
        $this->assertNotNull($response->json('subscription.valid_until'));
        $this->assertNull($response->json('subscription.locked_at'), 'Kilitsizken locked_at null olmalı.');
        $this->assertNotNull($response->json('subscription.server_time'));
    }

    #[Test]
    public function null_valid_until_kilitsizdir(): void
    {
        // En kritik regresyon koruması: valid_until NULL → kilitsiz (mevcut factory/test tenant'ları).
        $a = $this->makeTenant('a');
        $this->setTenant($a['tenant']->id, ['valid_until' => null, 'status' => 'trial', 'locked_at' => null]);
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Sınırsız'])])
            ->assertJsonPath('results.0.status', 'applied');
    }

    #[Test]
    public function suspended_bayide_kilit_sonrasi_yazim_locked_bekleyen_yazim_uygulanir(): void
    {
        $a = $this->makeTenant('a');
        $lockedAt = now()->subMinutes(5);
        $this->setTenant($a['tenant']->id, ['status' => 'suspended', 'locked_at' => $lockedAt]);
        $token = $this->tokenFor($a['patron']);

        // occurred_at <= locked_at (bekleyen offline yazım) → UYGULANIR; > locked_at (yeni yazım) → locked.
        $bekleyen = $this->customerUpsert(['name' => 'Bekleyen'], ['occurred_at' => now()->subMinutes(10)->toIso8601String()]);
        $yeni = $this->customerUpsert(['name' => 'Yeni'], ['occurred_at' => now()->toIso8601String()]);

        $response = $this->pushEvents($token, [$bekleyen, $yeni]);
        $response->assertOk();
        $response->assertJsonPath('results.0.status', 'applied');
        $response->assertJsonPath('results.1.status', 'locked');
        $response->assertJsonPath('subscription.status', 'suspended');

        // Yalnız bekleyen kayıt oluştu; yeni yazım kilitte kaldı.
        $count = $this->asOwner(fn () => Customer::query()->count());
        $this->assertSame(1, $count);
        $names = $this->asOwner(fn () => Customer::query()->pluck('name')->all());
        $this->assertSame(['Bekleyen'], $names);
    }

    #[Test]
    public function sure_dolunca_lazy_locked_at_valid_untile_esitlenir_sinir_dogru(): void
    {
        $a = $this->makeTenant('a');
        $validUntil = now()->subMinutes(30);
        // status hâlâ active ama süre dolmuş; locked_at NULL (henüz push tespit etmedi).
        $this->setTenant($a['tenant']->id, ['status' => 'active', 'valid_until' => $validUntil, 'locked_at' => null]);
        $token = $this->tokenFor($a['patron']);

        // valid_until'dan ÖNCE (bekleyen) → applied; SONRA (yeni) → locked.
        $once = $this->customerUpsert(['name' => 'Süreden Önce'], ['occurred_at' => now()->subHour()->toIso8601String()]);
        $sonra = $this->customerUpsert(['name' => 'Süreden Sonra'], ['occurred_at' => now()->toIso8601String()]);

        $response = $this->pushEvents($token, [$once, $sonra]);
        $response->assertJsonPath('results.0.status', 'applied');
        $response->assertJsonPath('results.1.status', 'locked');

        // locked_at LAZY olarak valid_until'a eşitlendi (ilk tespit eden push).
        $lockedAt = $this->asOwner(fn () => Tenant::query()->find($a['tenant']->id)->locked_at);
        $this->assertNotNull($lockedAt);
        $this->assertSame($validUntil->utc()->format('Y-m-d H:i:s'), $lockedAt->utc()->format('Y-m-d H:i:s'),
            'Süre dolumunda locked_at = valid_until olmalı.');
    }

    #[Test]
    public function locked_reddi_processed_eventse_yazilmaz_yenilenince_retry_uygulanir(): void
    {
        $a = $this->makeTenant('a');
        $this->setTenant($a['tenant']->id, ['status' => 'suspended', 'locked_at' => now()->subMinutes(5)]);
        $token = $this->tokenFor($a['patron']);

        // Kilitliyken yeni yazım → locked.
        $event = $this->customerUpsert(['name' => 'Yenilenecek'], ['occurred_at' => now()->toIso8601String()]);
        $this->pushEvents($token, [$event])->assertJsonPath('results.0.status', 'locked');
        $this->assertSame(0, $this->asOwner(fn () => Customer::query()->count()), 'Kilitli yazım uygulanmamalı.');

        // Abonelik yenilenir (panel/ödeme): status active, valid_until gelecek, locked_at temizlenir.
        $this->setTenant($a['tenant']->id, ['status' => 'active', 'valid_until' => now()->addYear(), 'locked_at' => null]);

        // AYNI olay (aynı client_event_id) retry → 'duplicate' DEĞİL 'applied' (processed_events'e yazılmamıştı).
        $retry = $this->pushEvents($token, [$event]);
        $retry->assertJsonPath('results.0.status', 'applied');
        $this->assertSame(1, $this->asOwner(fn () => Customer::query()->count()),
            'Yenilenince kilitli kalan yazım retry ile uygulanmalı (locked reddi kalıcı değil).');
    }

    #[Test]
    public function pull_asla_kilitlenmez_ve_subscription_yayinlar(): void
    {
        $a = $this->makeTenant('a');
        $this->setTenant($a['tenant']->id, ['status' => 'suspended', 'locked_at' => now()->subMinutes(5)]);
        $token = $this->tokenFor($a['patron']);

        // Okuma kilitliyken de çalışır (veri rehin alınmaz, kırmızı çizgi #5) + subscription taşır.
        $snap = $this->pullSince($token, 0);
        $snap->assertOk();
        $snap->assertJsonPath('mode', 'snapshot');
        $snap->assertJsonPath('subscription.status', 'suspended');
        $this->assertNotNull($snap->json('subscription.locked_at'));
        $this->assertNotNull($snap->json('subscription.server_time'));
    }

    #[Test]
    public function login_suresi_dolmus_bayi_403_gelecekteki_200(): void
    {
        $prov = Provisioning::createTenantWithPatron('Süre Bayii', 'sure@sipario.test', 'password', 'Süre Patron');
        $tenantId = $prov['tenant']->id;

        // Provisioning valid_until = now+30g (gelecek) → login 200.
        $this->postJson('/api/v1/auth/login', [
            'email' => 'sure@sipario.test', 'password' => 'password',
        ])->assertOk();

        // Süre geçmişe çekilir → login nötr 403 (status hâlâ trial olsa bile süre tek çıpa).
        $this->setTenant($tenantId, ['valid_until' => now()->subDay()]);
        $expired = $this->postJson('/api/v1/auth/login', [
            'email' => 'sure@sipario.test', 'password' => 'password',
        ]);
        $expired->assertStatus(403);
        $this->assertStringNotContainsString('süre', mb_strtolower($expired->json('message') ?? ''),
            'Mesaj nötr olmalı (süre-dolumu sebebini sızdırmadan).');
    }
}
