<?php

namespace App\Models;

use App\Enums\BillingPeriod;
use App\Enums\TenantStatus;
use Database\Factories\TenantFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * Bayi (kiracı). Tüm iş verisi bir tenant'a bağlıdır ve RLS ile izole edilir.
 * Kimlik UUIDv7 (HasUuids → Str::uuid7); tenant'ın kendisinde tenant_id yoktur.
 *
 * casts() ile türeyen gerçek tipler (statik analiz bunları kolon şemasından çıkaramaz):
 *
 * @property string $id
 * @property string $name
 * @property string $slug
 * @property TenantStatus $status
 * @property Carbon|null $trial_ends_at
 * @property Carbon|null $valid_until
 * @property Carbon|null $locked_at
 * @property array<string, mixed> $modules
 * @property string|null $phone
 * @property int $route_credits
 * @property int $route_credits_monthly
 * @property string|null $contact_name
 * @property string|null $city
 * @property string|null $district
 * @property int $courier_limit
 * @property BillingPeriod|null $billing_period
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class Tenant extends Model
{
    /** @use HasFactory<TenantFactory> */
    use HasFactory, HasUuids;

    protected $fillable = [
        'name',
        'slug',
        'status',
        'trial_ends_at',
        'valid_until',
        'locked_at',
        'modules',
        'phone',
        'route_credits',
        'route_credits_monthly',
        'contact_name',
        'city',
        'district',
        'courier_limit',
        'billing_period',
    ];

    protected function casts(): array
    {
        return [
            'status' => TenantStatus::class,
            'trial_ends_at' => 'datetime',
            'valid_until' => 'datetime',
            'locked_at' => 'datetime',
            'modules' => 'array',
            'route_credits' => 'integer',
            'route_credits_monthly' => 'integer',
            'courier_limit' => 'integer',
            'billing_period' => BillingPeriod::class,
        ];
    }

    /** @return HasMany<User, $this> */
    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    /** @return HasMany<Device, $this> */
    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }

    /**
     * Panelden tutulan satış/destek notları (append-only). Bayiye GÖSTERİLMEZ.
     *
     * @return HasMany<TenantNote, $this>
     */
    public function notes(): HasMany
    {
        return $this->hasMany(TenantNote::class)->orderByDesc('created_at');
    }

    /**
     * Bayiye tanımlanmış ek paketler (append-only).
     *
     * @return HasMany<AddonGrant, $this>
     */
    public function grants(): HasMany
    {
        return $this->hasMany(AddonGrant::class)->orderByDesc('granted_on');
    }
}
