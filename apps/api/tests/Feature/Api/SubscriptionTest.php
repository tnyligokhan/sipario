<?php

namespace Tests\Feature\Api;

use App\Livewire\Site\Login as SiteLogin;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use App\Models\User;
use App\Payment\ConsentRequiredException;
use App\Payment\DuplicateEmailException;
use App\Payment\FakePaymentGateway;
use App\Payment\PaymentGateway;
use App\Payment\SubscriptionService;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5b — abonelik/ödeme sitesi (DECISIONS "Faz 5 — mimari"). Ödeme SOYUT (PaymentGateway) → Fake ile
 * test. Abonelik durumu tek doğru kaynak SUNUCU (ödeme başarısı valid_until'ı uzatır). subscription_payments
 * append-only; callback idempotent; hukuk onayı zorunlu. Gerçek Postgres 16 + RLS'e koşar.
 */
class SubscriptionTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private FakePaymentGateway $gateway;

    protected function setUp(): void
    {
        parent::setUp();
        $this->gateway = new FakePaymentGateway;
        $this->app->instance(PaymentGateway::class, $this->gateway);
    }

    private function service(): SubscriptionService
    {
        return app(SubscriptionService::class);
    }

    /** @return array{tenant: Tenant, patron: User} */
    private function register(string $email = 'yeni@sipario.test'): array
    {
        return $this->service()->register('Yeni Bayi', $email, 'password123', '05551112233', true);
    }

    #[Test]
    public function uyelik_trial_tenant_ve_patron_yaratir(): void
    {
        $result = $this->register();

        $this->assertSame('trial', $result['tenant']->status->value);
        $this->assertNotNull($result['tenant']->valid_until);
        $this->assertTrue($result['tenant']->valid_until->isFuture(), 'trial valid_until gelecekte olmalı.');
        $this->assertSame('yeni@sipario.test', $result['patron']->email);

        $userCount = $this->asOwner(fn () => User::query()->where('email', 'yeni@sipario.test')->count());
        $this->assertSame(1, $userCount);
    }

    #[Test]
    public function uyelik_kvkk_onaysiz_reddedilir(): void
    {
        $this->expectException(ConsentRequiredException::class);
        $this->service()->register('Bayi', 'k@sipario.test', 'password123', null, false);
    }

    #[Test]
    public function uyelik_ayni_email_notr_hata_verir(): void
    {
        $this->register('cakisan@sipario.test');
        $this->expectException(DuplicateEmailException::class);
        $this->register('cakisan@sipario.test');
    }

    #[Test]
    public function odeme_basarisi_aboneligi_aktive_eder_ve_5a_ile_tutarli(): void
    {
        $result = $this->register('odeme@sipario.test');
        $tenantId = $result['tenant']->id;
        $token = $this->tokenFor($result['patron']);

        // Süreyi geçmişe çekip kilitle (5a: yeni yazım kilitli).
        $this->asOwner(fn () => Tenant::query()->whereKey($tenantId)
            ->update(['status' => 'locked', 'valid_until' => now()->subDay(), 'locked_at' => now()->subDay()]));
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Kilitli'], ['occurred_at' => now()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'locked');

        // Ödeme akışı: checkout → başarılı callback → aktivasyon.
        $this->gateway->forcedProviderRef = 'ref-ok';
        $this->service()->startCheckout($tenantId, 'odeme@sipario.test', $this->consents());
        $this->service()->handleCallback(['provider_ref' => 'ref-ok', 'success' => true]);

        $tenant = $this->asOwner(fn () => Tenant::query()->find($tenantId));
        $this->assertSame('active', $tenant->status->value);
        $this->assertTrue($tenant->valid_until->isFuture());
        $this->assertNull($tenant->locked_at, 'Aktivasyon kilidi temizlemeli.');
        $this->assertTrue($tenant->valid_until->greaterThan(now()->addDays(300)), 'Yıllık abonelik ~1 yıl ileri.');

        // subscription_payments success kaydı.
        $success = $this->asOwner(fn () => SubscriptionPayment::query()
            ->where('tenant_id', $tenantId)->where('status', 'success')->count());
        $this->assertSame(1, $success);

        // 5a tutarlılık: artık aktif → push 'applied'.
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Aktif'])])
            ->assertJsonPath('results.0.status', 'applied');
    }

    #[Test]
    public function odeme_basarisizligi_durumu_degistirmez(): void
    {
        $result = $this->register('basarisiz@sipario.test');
        $tenantId = $result['tenant']->id;

        $this->gateway->forcedProviderRef = 'ref-fail';
        $this->service()->startCheckout($tenantId, 'basarisiz@sipario.test', $this->consents());
        $this->service()->handleCallback(['provider_ref' => 'ref-fail', 'success' => false]);

        $tenant = $this->asOwner(fn () => Tenant::query()->find($tenantId));
        $this->assertSame('trial', $tenant->status->value, 'Başarısız ödeme durumu değiştirmemeli.');

        $failed = $this->asOwner(fn () => SubscriptionPayment::query()
            ->where('tenant_id', $tenantId)->where('status', 'failed')->count());
        $this->assertSame(1, $failed);
        $successCount = $this->asOwner(fn () => SubscriptionPayment::query()
            ->where('tenant_id', $tenantId)->where('status', 'success')->count());
        $this->assertSame(0, $successCount);
    }

    #[Test]
    public function callback_idempotenttir_ayni_ref_iki_kez_tek_aktivasyon(): void
    {
        $result = $this->register('idempotent@sipario.test');
        $tenantId = $result['tenant']->id;

        $this->gateway->forcedProviderRef = 'ref-dup';
        $this->service()->startCheckout($tenantId, 'idempotent@sipario.test', $this->consents());

        $this->service()->handleCallback(['provider_ref' => 'ref-dup', 'success' => true]);
        $this->service()->handleCallback(['provider_ref' => 'ref-dup', 'success' => true]); // retry/webhook 2×

        $successRows = $this->asOwner(fn () => SubscriptionPayment::query()
            ->where('provider_ref', 'ref-dup')->where('status', 'success')->count());
        $this->assertSame(1, $successRows, 'Aynı provider_ref için tek success (idempotent).');
    }

    #[Test]
    public function checkout_hukuk_onayi_isaretsiz_reddedilir_odeme_baslamaz(): void
    {
        $result = $this->register('onaysiz@sipario.test');
        $tenantId = $result['tenant']->id;

        try {
            $this->service()->startCheckout($tenantId, 'onaysiz@sipario.test', ['distance_sales' => true, 'preinfo' => false, 'kvkk' => true]);
            $this->fail('Eksik onayla checkout reddedilmeliydi.');
        } catch (ConsentRequiredException) {
            // beklenen
        }

        $count = $this->asOwner(fn () => SubscriptionPayment::query()->where('tenant_id', $tenantId)->count());
        $this->assertSame(0, $count, 'Onaysız checkout hiçbir ödeme kaydı üretmemeli.');
    }

    #[Test]
    public function subscription_payments_append_only_update_delete_reddedilir(): void
    {
        // sipario_app (RLS) bağlantısıyla UPDATE/DELETE → 42501 (append-only, ledger deseni).
        try {
            DB::statement('UPDATE subscription_payments SET status = status');
            $this->fail('subscription_payments UPDATE reddedilmeliydi.');
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode());
        }

        try {
            DB::statement('DELETE FROM subscription_payments');
            $this->fail('subscription_payments DELETE reddedilmeliydi.');
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode());
        }
    }

    #[Test]
    public function kayit_ekrani_gorunur_ve_abonelik_oturumsuz_reddeder(): void
    {
        $this->get('/kayit')->assertOk()->assertSee('Üyelik');
        $this->get('/giris')->assertOk()->assertSee('Giriş');
        // Oturumda tenant yoksa /abonelik 403 (önce üyelik/giriş).
        $this->get('/abonelik')->assertForbidden();
    }

    #[Test]
    public function web_login_gecerli_patron_aboneligi_acar(): void
    {
        $a = $this->makeTenant('a'); // patron parolası UserFactory ile 'password'

        Livewire::test(SiteLogin::class)
            ->set('email', $a['patron']->email)
            ->set('password', 'password')
            ->call('authenticate')
            ->assertRedirect(route('subscription.subscribe'));

        $this->assertSame($a['tenant']->id, session('subscription_tenant_id'), 'Login web session tenant bağlamını kurmalı.');
        // Session kurulunca /abonelik erişilebilir (Subscribe.mount yalnız session'a bakar).
        $this->withSession(['subscription_tenant_id' => $a['tenant']->id, 'subscription_email' => $a['patron']->email])
            ->get('/abonelik')->assertOk();
    }

    #[Test]
    public function web_login_yanlis_parola_notr_hata_verir(): void
    {
        $a = $this->makeTenant('a');

        Livewire::test(SiteLogin::class)
            ->set('email', $a['patron']->email)
            ->set('password', 'yanlis-parola')
            ->call('authenticate')
            ->assertHasErrors('email');

        $this->assertNull(session('subscription_tenant_id'), 'Yanlış parola oturum kurmamalı.');
    }

    #[Test]
    public function web_login_olmayan_email_notr_hata_verir(): void
    {
        // E-posta var/yok ayrımı sızmaz (numaralandırma önlenir); dummy-hash zamanlama koruması.
        Livewire::test(SiteLogin::class)
            ->set('email', 'yok@sipario.test')
            ->set('password', 'herhangi')
            ->call('authenticate')
            ->assertHasErrors('email');

        $this->assertNull(session('subscription_tenant_id'));
    }

    #[Test]
    public function web_login_suresi_dolmus_bayiye_odeme_icin_izin_verir(): void
    {
        // API login'in AKSİNE: billing sitesi süresi dolmuş bayinin GİRİŞİNE izin verir (ödeme yapsın).
        $a = $this->makeTenant('a');
        $this->asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)
            ->update(['status' => 'locked', 'valid_until' => now()->subDay(), 'locked_at' => now()->subDay()]));

        Livewire::test(SiteLogin::class)
            ->set('email', $a['patron']->email)
            ->set('password', 'password')
            ->call('authenticate')
            ->assertRedirect(route('subscription.subscribe'));

        $this->assertSame($a['tenant']->id, session('subscription_tenant_id'),
            'Süresi dolmuş bayi ödeme için giriş yapabilmeli (billing sitesi).');
    }

    /** @return array<string, bool> */
    private function consents(): array
    {
        return ['distance_sales' => true, 'preinfo' => true, 'kvkk' => true];
    }
}
