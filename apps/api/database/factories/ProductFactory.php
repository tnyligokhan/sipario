<?php

namespace Database\Factories;

use App\Models\Product;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    protected $model = Product::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'tenant_id' => Tenant::factory(),
            'name' => fake()->randomElement(['19L Damacana', '10L Damacana', '0.5L Pet Su (12li)', '5L Bidon']),
            'unit_price_kurus' => fake()->randomElement([4500, 6000, 9000, 12000]),
            'unit' => 'adet',
            'is_active' => true,
            'updated_occurred_at' => now(),
            'updated_device_id' => null,
        ];
    }
}
