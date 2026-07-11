<?php

namespace Database\Factories;

use App\Models\Device;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Device>
 */
class DeviceFactory extends Factory
{
    protected $model = Device::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'tenant_id' => Tenant::factory(),
            'user_id' => null,
            'platform' => 'android',
            'model' => fake()->randomElement(['Xiaomi 14', 'Redmi Note 13', 'Samsung S24 FE', 'Poco X6']),
            'os_version' => fake()->randomElement(['Android 14', 'HyperOS 2 / Android 14', 'Android 16']),
            'app_version' => '1.0.0',
            'push_token' => null,
            'last_seen_at' => now(),
        ];
    }
}
