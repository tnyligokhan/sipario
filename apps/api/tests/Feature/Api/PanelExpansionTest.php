<?php

namespace Tests\Feature\Api;

use App\Models\AdminUser;
use App\Models\Device;
use App\Models\Order;
use App\Models\Tenant;
use App\Models\User;
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

    /**
     * Bir bayi için 12 export tablosunun HEPSİNE veri tohumlar (push API + makeTenant cihazı).
     * Döner: bu bayinin json'da aranacak ayırt edici id'leri.
     *
     * @param  array{tenant: Tenant, patron: User, kurye: User, device: Device}  $seed
     * @return list<string>
     */
    private function seedFullDataset(string $token, array $seed): array
    {
        $cust = $this->customerUpsert(['name' => 'Müşteri']);
        $cid = $cust['payload']['id'];
        $prod = $this->event('product', 'upsert', ['id' => (string) Str::uuid7(), 'name' => 'Ürün', 'unit_price_kurus' => 1000]);
        $pid = $prod['payload']['id'];
        $this->pushEvents($token, [$cust, $prod])->assertOk();

        $phone = $this->event('customer_phone', 'upsert', ['id' => (string) Str::uuid7(), 'customer_id' => $cid, 'phone_e164' => '+905321112233']);
        $addr = $this->event('customer_address', 'upsert', ['id' => (string) Str::uuid7(), 'customer_id' => $cid, 'address_text' => 'Adres']);
        $this->pushEvents($token, [$phone, $addr])->assertOk();

        $order = $this->orderCreated([$this->line(['product_id' => $pid])], ['customer_id' => $cid]);
        $oid = $order['payload']['order']['id'];
        $this->pushEvents($token, [$order])->assertOk();
        $this->pushEvents($token, [$this->orderEvent('delivered', ['order_id' => $oid, 'payment_type' => 'nakit'])])->assertOk();

        // Defter (debit+payment) + kupon (movement+balance) + kasa devri.
        $this->pushEvents($token, [
            $this->ledgerEntry(['customer_id' => $cid, 'entry_type' => 'debit', 'amount_kurus' => 9000, 'related_order_id' => $oid]),
            $this->ledgerEntry(['customer_id' => $cid, 'entry_type' => 'payment', 'amount_kurus' => -9000, 'payment_type' => 'nakit', 'related_order_id' => $oid]),
            $this->couponMovement('grant', ['customer_id' => $cid, 'qty_delta' => 5]),
            $this->cashHandover(['from_user_id' => $seed['kurye']->id, 'counted_cash_kurus' => 9000, 'expected_cash_kurus' => 9000]),
        ])->assertOk();

        // 12 tablonun her birinde aranacak ayırt edici id'ler (devices makeTenant'tan).
        return [$cid, $pid, $oid, $phone['payload']['id'], $addr['payload']['id'], $seed['device']->id];
    }

    #[Test]
    public function export_tum_tablolarda_bayinin_verisini_verir_baska_bayininki_sizmaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $idsA = $this->seedFullDataset($this->tokenFor($a['patron']), $a);
        $idsB = $this->seedFullDataset($this->tokenFor($b['patron']), $b);

        $export = (new PanelExportService('pgsql_panel'))->export($a['tenant']->id);
        $json = (string) json_encode($export);

        // 12 export tablosunun HEPSİ mevcut ve A için DOLU (tam kapsama).
        foreach (['customers', 'customer_phones', 'customer_addresses', 'products', 'orders', 'order_lines',
            'order_events', 'ledger_entries', 'coupon_movements', 'coupon_balances', 'cash_handovers', 'devices'] as $table) {
            $this->assertArrayHasKey($table, $export, "Export {$table} tablosunu içermeli.");
            $this->assertNotEmpty($export[$table], "A'nın {$table} verisi export'ta DOLU olmalı.");
        }

        // A'nın id'leri VAR; B'nin HİÇBİR id'si (12 tablonun hiçbirinden) A export'una SIZMAZ.
        foreach ($idsA as $id) {
            $this->assertStringContainsString($id, $json, "A'nın verisi ({$id}) export'ta olmalı.");
        }
        foreach ($idsB as $id) {
            $this->assertStringNotContainsString($id, $json, "B'nin verisi ({$id}) A export'una SIZMAMALI.");
        }
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
