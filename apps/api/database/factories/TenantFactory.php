<?php

namespace Database\Factories;

use App\Abonelik\RotaKontoru;
use App\Enums\TenantStatus;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Tenant>
 */
class TenantFactory extends Factory
{
    protected $model = Tenant::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'name' => fake()->company().' Su Bayii',
            // Firma kodu (tasarımda "Firma Kodu") artık ZORUNLU: giriş ekranının ilk alanı.
            // Kural ^[a-z0-9-]{3,80}$ — DB'de CHECK ile de sabit.
            'slug' => 'bayi-'.fake()->unique()->numberBetween(1, 999999),
            'status' => TenantStatus::Trial->value,
            'trial_ends_at' => now()->addDays(30),
            'valid_until' => null,
            'phone' => fake()->numerify('05#########'),
            // Açılışla (Provisioning) tutarlı: yeni bayi bu ayın oto-sıralama hakkını almış sayılır.
            // Boş kalsaydı uç noktadaki ay başı yenilemesi testin ayarladığı hakkı ezerdi.
            'route_credits_renewed_on' => RotaKontoru::donemBasi(),
        ];
    }

    public function active(): static
    {
        return $this->state(fn () => [
            'status' => TenantStatus::Active->value,
            'valid_until' => now()->addYear(),
        ]);
    }
}
