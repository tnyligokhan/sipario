<?php

namespace Database\Seeders;

use App\Models\Device;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * İki bayi (A, B) + her birine patron/operator/kurye + birkaç cihaz. İzolasyon testleri ve
 * manuel deneme için. Provizyon owner bağlamında koşar (RLS meşru olarak atlanır); parolalar 'password'.
 */
class TenantSeeder extends Seeder
{
    public function run(): void
    {
        Provisioning::asOwner(function () {
            $this->makeTenant('A Su Bayii', 'a');
            $this->makeTenant('B Su Bayii', 'b');
        });
    }

    private function makeTenant(string $name, string $prefix): void
    {
        // Firma kodu = giriş ekranının ilk alanı; seed'de öngörülebilir olsun ("a-su-bayii").
        $tenant = Tenant::factory()->create([
            'name' => $name,
            'slug' => Provisioning::benzersizKod($name),
        ]);

        $password = Hash::make('password');

        // Kullanıcı adları tenant içinde tekildir; iki bayide de aynı üçlü kullanılır.
        User::factory()->patron()->create([
            'tenant_id' => $tenant->id,
            'name' => strtoupper($prefix).' Patron',
            'email' => "{$prefix}-patron@sipario.test",
            'username' => 'patron',
            'password' => $password,
        ]);
        User::factory()->operator()->create([
            'tenant_id' => $tenant->id,
            'name' => strtoupper($prefix).' Operator',
            'email' => "{$prefix}-operator@sipario.test",
            'username' => 'operator',
            'password' => $password,
        ]);
        // Kurye TEK MEŞRU YOLDAN açılır: Provisioning::createCourier kota kapısından geçer
        // (App\Abonelik\KuryeKotasi). Seeder'ın kapıyı atlaması, kotanın çalıştığı yanılsamasını
        // üretirdi. Bayi başına 1 kurye, hak 3 → kapı açık.
        Provisioning::createCourier($tenant, strtoupper($prefix).' Kurye', 'kurye', $password);

        Device::factory()->count(2)->create(['tenant_id' => $tenant->id]);
    }
}
