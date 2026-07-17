<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\Login;
use App\Models\AdminUser;
use App\Models\Tenant;
use App\Panel\TenantAdminService;
use App\Support\Provisioning;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-1 — yönetim paneli temeli (DECISIONS "Faz 5 — mimari"; BRIEF panel sınırı).
 *
 * KIRMIZI ÇİZGİ: panel bayinin iş verisini DEĞİŞTİREMEZ — DB izniyle zorlanır (sipario_panel iş
 * tablolarında yalnız SELECT). Panel abonelik/durum yönetir (tenants UPDATE) ve bu 5a kilidiyle
 * tutarlıdır. admin_users bayilerden ayrı guard. Gerçek Postgres 16'ya koşar.
 */
class PanelTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function service(): TenantAdminService
    {
        return new TenantAdminService('pgsql_panel');
    }

    private function makeAdmin(string $email = 'admin@sipario.test', string $role = 'superadmin'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Panel Admin',
            'email' => $email,
            'password' => 'panel-secret',
            'role' => $role,
        ]));
    }

    /**
     * TAM iş verisi matrisi (13 tablo): panel yalnız SELECT'e sahip; UPDATE/DELETE hepsinde 42501.
     *
     * @return list<array{string}>
     */
    public static function businessTables(): array
    {
        return [
            ['customers'], ['customer_phones'], ['customer_addresses'], ['products'],
            ['orders'], ['order_lines'], ['order_events'], ['ledger_entries'],
            ['coupon_movements'], ['coupon_balances'], ['cash_handovers'], ['devices'], ['users'],
        ];
    }

    #[Test]
    #[DataProvider('businessTables')]
    public function panel_rolu_is_verisine_update_yapamaz(string $table): void
    {
        // KIRMIZI ÇİZGİ: panel iş verisini fiziksel olarak değiştiremez (grant matrisinde INSERT/UPDATE yok).
        try {
            DB::connection('pgsql_panel')->statement("UPDATE {$table} SET tenant_id = tenant_id");
            $this->fail("{$table} panel rolüyle UPDATE reddedilmeliydi (yalnız SELECT).");
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode(), "{$table} UPDATE için permission denied beklenir.");
        }
    }

    #[Test]
    #[DataProvider('businessTables')]
    public function panel_rolu_is_verisine_delete_yapamaz(string $table): void
    {
        try {
            DB::connection('pgsql_panel')->statement("DELETE FROM {$table}");
            $this->fail("{$table} panel rolüyle DELETE reddedilmeliydi.");
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode(), "{$table} DELETE için permission denied beklenir.");
        }
    }

    #[Test]
    public function panel_rolu_is_verisini_cross_tenant_okuyabilir(): void
    {
        // Panel BYPASSRLS ile tüm bayileri okur (destek/istatistik); okuma reddedilmez.
        $this->makeTenant('a');
        $this->makeTenant('b');
        $count = DB::connection('pgsql_panel')->table('tenants')->count();
        $this->assertGreaterThanOrEqual(2, $count, 'Panel cross-tenant tüm bayileri görebilmeli.');
    }

    #[Test]
    public function panel_kilitleme_api_pushunu_5a_ile_tutarli_kilitler(): void
    {
        $a = $this->makeTenant('a'); // aktif, valid_until gelecek → kilitsiz
        $token = $this->tokenFor($a['patron']);
        $admin = $this->makeAdmin();

        // Kilitten ÖNCE push çalışır.
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Önce'])])
            ->assertJsonPath('results.0.status', 'applied');

        // Panel kilitler (tenants UPDATE, panel bağlantısı).
        $this->service()->lock($a['tenant']->id, $admin->id);

        // Kilit sonrası YENİ yazım (occurred_at şimdi > locked_at) → 5a 'locked'.
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Sonra'], ['occurred_at' => now()->addSecond()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'locked');

        // Panel abonelik kaydeder → tekrar açılır, push 'applied'.
        $this->service()->activateSubscription($a['tenant']->id, 365, $admin->id);
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Yenilendi'])])
            ->assertJsonPath('results.0.status', 'applied');
    }

    #[Test]
    public function panel_deneme_uzatma_tarihi_ileri_alir(): void
    {
        $a = $this->makeTenant('a');
        // Süresi dolmuş bir bayi kur.
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)
            ->update(['status' => 'locked', 'valid_until' => now()->subDay(), 'locked_at' => now()->subDay()]));

        $updated = $this->service()->extendTrial($a['tenant']->id, 14);

        $this->assertSame('trial', $updated->status->value);
        $this->assertTrue($updated->valid_until->isFuture(), 'Deneme uzatınca valid_until ileri alınmalı.');
        $this->assertNull($updated->locked_at, 'Uzatma kilidi temizlemeli.');
    }

    #[Test]
    public function panel_elle_tenant_acar_trial_valid_until_dogru(): void
    {
        $admin = $this->makeAdmin();

        $result = $this->service()->createTenant('Elle Bayi', 'elle@sipario.test', 'password', $admin->id);

        $this->assertSame('trial', $result['tenant']->status->value);
        $this->assertNotNull($result['tenant']->valid_until, 'Elle açılan bayi valid_until almalı (trial).');
        $this->assertTrue($result['tenant']->valid_until->isFuture());
        // Denetim kaydı düştü.
        $audit = DB::connection('pgsql_panel')->table('panel_audit')
            ->where('action', 'create_tenant')->where('tenant_id', $result['tenant']->id)->count();
        $this->assertSame(1, $audit);
    }

    #[Test]
    public function admin_guard_bayilerden_ayridir(): void
    {
        $a = $this->makeTenant('a');
        $this->makeAdmin('gercek-admin@sipario.test');

        // Geçerli admin, admin guard'ında doğrulanır.
        $this->assertTrue(
            Auth::guard('admin')->attempt(['email' => 'gercek-admin@sipario.test', 'password' => 'panel-secret']),
            'Geçerli admin panel guard\'ına girebilmeli.'
        );

        // Bayinin kullanıcısı (users tablosu) admin guard'ına GİREMEZ (ayrı provider/tablo).
        $this->assertFalse(
            Auth::guard('admin')->attempt(['email' => $a['patron']->email, 'password' => 'password']),
            'Bayi kullanıcısı panel admin guard\'ına asla giremez.'
        );
    }

    #[Test]
    public function panel_denetim_gunlugu_eylemleri_kaydeder(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $this->service()->lock($a['tenant']->id, $admin->id);
        $this->service()->unlock($a['tenant']->id, $admin->id);

        $actions = DB::connection('pgsql_panel')->table('panel_audit')
            ->where('tenant_id', $a['tenant']->id)->orderBy('created_at')->pluck('action')->all();
        $this->assertSame(['lock', 'unlock'], $actions);
    }

    // --- Panel UI (Livewire) wiring -----------------------------------------------------

    #[Test]
    public function panel_login_ekrani_gorunur(): void
    {
        $this->get('/panel/login')->assertOk()->assertSee('Giriş');
    }

    #[Test]
    public function panel_oturumsuz_istek_login_e_yonlendirir(): void
    {
        $this->get('/panel')->assertRedirect(route('panel.login'));
        $this->get('/panel/tenants/'.Str::uuid7())->assertRedirect(route('panel.login'));
    }

    #[Test]
    public function panel_admin_girisi_sonrasi_bayi_listesini_gorur(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $this->actingAs($admin, 'admin')->get('/panel')
            ->assertOk()
            ->assertSee($a['tenant']->name);
    }

    #[Test]
    public function livewire_login_gecerli_admini_dogrular_ve_yonlendirir(): void
    {
        $this->makeAdmin('lw-admin@sipario.test');

        Livewire::test(Login::class)
            ->set('email', 'lw-admin@sipario.test')
            ->set('password', 'panel-secret')
            ->call('authenticate')
            ->assertRedirect(route('panel.tenants'));

        $this->assertTrue(Auth::guard('admin')->check(), 'Livewire login sonrası admin oturumu açık olmalı.');
    }

    #[Test]
    public function livewire_login_yanlis_parolayi_reddeder(): void
    {
        $this->makeAdmin('lw-admin2@sipario.test');

        Livewire::test(Login::class)
            ->set('email', 'lw-admin2@sipario.test')
            ->set('password', 'yanlis')
            ->call('authenticate')
            ->assertHasErrors('email');

        $this->assertFalse(Auth::guard('admin')->check());
    }
}
