<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\CustomerPhone;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\Tenant;
use App\Models\User;
use Database\Seeders\DemoSeeder;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * Mağaza inceleme DEMO hesabı (Faz 6 gereksinimi). Seeder içi dolu, AKTİF, telefonlu bir demo bayi
 * kurmalı ki incelemeci mobil uygulamaya girip arayan-tanıma + dolu defteri görebilsin.
 */
class DemoSeederTest extends ApiTestCase
{
    #[Test]
    public function demo_seeder_ici_dolu_aktif_telefonlu_bir_bayi_kurar(): void
    {
        $this->seed(DemoSeeder::class);

        $this->asOwner(function () {
            $patron = User::query()->where('email', DemoSeeder::DEMO_EMAIL)->first();
            $this->assertNotNull($patron, 'Demo patron kullanıcı oluşmalı.');
            // Kimlik geçerli (incelemeci giriş yapabilmeli) + tenant aktif + valid_until gelecekte (kilitlenmez).
            $this->assertTrue(Hash::check(DemoSeeder::DEMO_PASSWORD, $patron->password));
            $tenant = Tenant::query()->findOrFail($patron->tenant_id);
            $this->assertSame('active', $tenant->status->value);
            $this->assertTrue($tenant->valid_until->isFuture());

            // 4 müşteri, HEPSİ telefonlu → arayan-tanıma demosu çalışır.
            $this->assertSame(4, Customer::query()->where('tenant_id', $tenant->id)->count());
            $this->assertSame(4, CustomerPhone::query()->where('tenant_id', $tenant->id)->count());

            // Teslim edilmiş siparişler + defter kayıtları (dolu defter).
            $this->assertGreaterThanOrEqual(3, Order::query()->where('tenant_id', $tenant->id)->count());
            $this->assertGreaterThan(0, LedgerEntry::query()->where('tenant_id', $tenant->id)->count());

            // Veresiye borç türetildi: en az bir müşterinin balance_kurus > 0 (borçlu), en az biri 0 (peşin).
            $borclu = Customer::query()->where('tenant_id', $tenant->id)->where('balance_kurus', '>', 0)->count();
            $borcsuz = Customer::query()->where('tenant_id', $tenant->id)->where('balance_kurus', 0)->count();
            $this->assertGreaterThan(0, $borclu, 'Veresiye borçlu müşteri olmalı.');
            $this->assertGreaterThan(0, $borcsuz, 'Borcu olmayan müşteri de olmalı.');
        });
    }

    #[Test]
    public function demo_seeder_idempotenttir_ikinci_kosuda_ikizlemez(): void
    {
        $this->seed(DemoSeeder::class);
        $this->seed(DemoSeeder::class); // ikinci kez — atlanmalı

        $this->asOwner(function () {
            $this->assertSame(1, User::query()->where('email', DemoSeeder::DEMO_EMAIL)->count());
        });
    }
}
