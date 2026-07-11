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
        $tenant = Tenant::factory()->create(['name' => $name]);

        $password = Hash::make('password');

        User::factory()->patron()->create([
            'tenant_id' => $tenant->id,
            'name' => strtoupper($prefix).' Patron',
            'email' => "{$prefix}-patron@sipario.test",
            'password' => $password,
        ]);
        User::factory()->operator()->create([
            'tenant_id' => $tenant->id,
            'name' => strtoupper($prefix).' Operator',
            'email' => "{$prefix}-operator@sipario.test",
            'password' => $password,
        ]);
        User::factory()->kurye()->create([
            'tenant_id' => $tenant->id,
            'name' => strtoupper($prefix).' Kurye',
            'email' => "{$prefix}-kurye@sipario.test",
            'password' => $password,
        ]);

        Device::factory()->count(2)->create(['tenant_id' => $tenant->id]);
    }
}
