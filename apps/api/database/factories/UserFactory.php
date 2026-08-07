<?php

namespace Database\Factories;

use App\Enums\UserRole;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    protected $model = User::class;

    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'tenant_id' => Tenant::factory(),
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            // Tasarım kuralı: ^[a-z0-9._-]{3,}$ (DB'de CHECK ile de sabit). Testlerde çakışmasın
            // diye unique sayaçla üretilir; gerçek hayatta panelden elle verilir.
            'username' => 'kullanici'.fake()->unique()->numberBetween(1, 999999),
            'password' => static::$password ??= Hash::make('password'),
            'role' => UserRole::Patron->value,
            'status' => 'active',
            'phone' => fake()->numerify('05#########'),
        ];
    }

    public function patron(): static
    {
        return $this->state(fn () => ['role' => UserRole::Patron->value]);
    }

    public function operator(): static
    {
        return $this->state(fn () => ['role' => UserRole::Operator->value]);
    }

    public function kurye(): static
    {
        return $this->state(fn () => ['role' => UserRole::Kurye->value]);
    }

    public function disabled(): static
    {
        return $this->state(fn () => ['status' => 'disabled']);
    }
}
