<?php

namespace Tests\Feature\Api;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\Tenant;
use App\Panel\PanelExportService;
use App\Panel\PanelStatsService;
use App\Panel\TenantAdminService;
use App\Support\Provisioning;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-2 — panel GENİŞLETME (BRIEF panel yetenekleri): istatistik (churn), export, modül aç/kapa,
 * patron şifre sıfırlama, cihaz listesi. Panel iş verisini OKUR (BYPASSRLS SELECT), YAZAMAZ; modül
 * tenants UPDATE, şifre sıfırlama owner ile. Gerçek Postgres 16 + RLS'e koşar.
 */
class PanelExpansionTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function admin(): TenantAdminService
    {
        return new TenantAdminService('pgsql_panel');
    }

    private function stats(): PanelStatsService
    {
        return new PanelStatsService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Admin', 'email' => 'exp-admin@sipario.test', 'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /** Owner ile belirli occurred_at'te sipariş ekler (istatistik testleri için kontrollü veri). */
    private function seedOrder(string $tenantId, Carbon $at): void
    {
        Provisioning::asOwner(fn () => Order::query()->create([
            'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId,
            'status' => 'open', 'total_kurus' => 0, 'occurred_at' => $at,
        ]));
    }

    #[Test]
    public function istatistik_gunluk_siparis_saat_dagilimi_ve_aktif_cihaz_dogru(): void
    {
        $a = $this->makeTenant('a');
        $tenantId = $a['tenant']->id;

        $t = now();
        $trDate = $t->copy()->utc()->addHours(3)->format('Y-m-d');
        $trHour = (int) $t->copy()->utc()->addHours(3)->format('G');
        $this->seedOrder($tenantId, $t);
        $this->seedOrder($tenantId, $t);
        $this->seedOrder($tenantId, $t);

        // Cihazı aktif yap (makeTenant bir cihaz kurar).
        Provisioning::asOwner(fn () => DB::table('devices')->where('tenant_id', $tenantId)->update(['last_seen_at' => now()]));

        $daily = $this->stats()->dailyOrders($tenantId);
        $this->assertSame(3, $daily[$trDate] ?? 0, 'Bugünkü TR sipariş sayısı 3 olmalı.');

        $hours = $this->stats()->orderHourDistribution($tenantId);
        $this->assertSame(3, $hours[$trHour], 'Saat dağılımı doğru TR saatinde 3 göstermeli.');

        $this->assertSame(1, $this->stats()->activeDeviceCount($tenantId), 'Bir aktif cihaz.');
        $this->assertNotNull($this->stats()->minutesToFirstOrder($tenantId), 'İlk siparişe süre hesaplanmalı.');
    }

    #[Test]
    public function export_bayinin_verisini_verir_baska_bayininki_sizmaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $custA = $this->customerUpsert(['name' => 'A Müşterisi']);
        $custB = $this->customerUpsert(['name' => 'B Müşterisi']);
        $this->pushEvents($tokenA, [$custA])->assertOk();
        $this->pushEvents($tokenB, [$custB])->assertOk();

        $export = (new PanelExportService('pgsql_panel'))->export($a['tenant']->id);
        $json = json_encode($export);

        $this->assertStringContainsString($custA['payload']['id'], (string) $json, 'A\'nın verisi export\'ta olmalı.');
        $this->assertStringNotContainsString($custB['payload']['id'], (string) $json, 'B\'nin verisi A export\'una SIZMAMALI.');
        $this->assertCount(1, $export['customers']);
    }

    #[Test]
    public function modul_ac_kapa_kalici_ve_subscription_bloguyla_yayinlanir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        $this->admin()->setModule($a['tenant']->id, 'empty_tracking', true, $admin->id);

        $modules = $this->asOwner(fn () => Tenant::query()->find($a['tenant']->id)->modules);
        $this->assertTrue($modules['empty_tracking'], 'Modül bayrağı kalıcı olmalı.');

        // İstemci subscription bloğuyla alır.
        $push = $this->pushEvents($token, [$this->customerUpsert(['name' => 'X'])]);
        $push->assertJsonPath('subscription.modules.empty_tracking', true);

        // Modül UPDATE panel ile oldu ama iş tablosu yazma HÂLÂ 42501 (kırmızı çizgi korunur).
        try {
            DB::connection('pgsql_panel')->statement('UPDATE orders SET status = status');
            $this->fail('Panel iş verisine yazamamalı.');
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode());
        }
    }

    #[Test]
    public function patron_sifre_sifirlama_owner_ile_yeni_parolayla_login(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        // Eski parola ('password') ile login çalışır.
        $this->postJson('/api/v1/auth/login', ['email' => $a['patron']->email, 'password' => 'password'])->assertOk();

        $newPassword = $this->admin()->resetPatronPassword($a['tenant']->id, $admin->id);

        // Yeni parola login olur; eski parola artık 401.
        $this->postJson('/api/v1/auth/login', ['email' => $a['patron']->email, 'password' => $newPassword])->assertOk();
        $this->postJson('/api/v1/auth/login', ['email' => $a['patron']->email, 'password' => 'password'])->assertStatus(401);

        // Panel rolü users'a YAZAMAZ (şifre sıfırlama owner ile yapıldı, panel ile değil).
        try {
            DB::connection('pgsql_panel')->statement('UPDATE users SET name = name');
            $this->fail('Panel users\'a yazamamalı.');
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode());
        }

        // Audit'e parola DEĞERİ yazılmadı — yalnız reset_password + user id.
        $detail = $this->asOwner(fn () => DB::connection('pgsql_panel')->table('panel_audit')
            ->where('action', 'reset_password')->value('detail'));
        $this->assertStringNotContainsString($newPassword, (string) $detail, 'Parola değeri audit\'e yazılmamalı.');
        $this->assertStringContainsString('user:', (string) $detail);
    }

    #[Test]
    public function cihaz_listesi_dogru_ve_cross_tenant_sizmaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $devicesA = $this->stats()->devices($a['tenant']->id);
        $this->assertCount(1, $devicesA, 'A yalnız kendi cihazını görmeli.');
        $ids = $devicesA->pluck('id')->all();
        $this->assertContains($a['device']->id, $ids);
        $this->assertNotContains($b['device']->id, $ids, 'B\'nin cihazı A listesine sızmamalı.');
    }
}
