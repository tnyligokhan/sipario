<?php

namespace App\Models;

use Database\Factories\CustomerFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * Bayinin müşterisi. Kimlik UUIDv7, istemcide üretilir (offline-first). RLS: tenant_id policy'sine tabidir.
 *
 * balance_kurus OKUMA-MODELİ ÖNBELLEĞİdir (DECISIONS: kaynak ledger_entries). updated_occurred_at/
 * updated_device_id LWW meta'sıdır. deleted_at tombstone (fiziksel silme yok).
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $name
 * @property string|null $note
 * @property int $balance_kurus
 * @property Carbon $updated_occurred_at
 * @property string|null $updated_device_id
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class Customer extends Model
{
    /** @use HasFactory<CustomerFactory> */
    use HasFactory, HasUuids;

    protected $fillable = [
        'id',
        'tenant_id',
        'name',
        'note',
        'balance_kurus',
        'updated_occurred_at',
        'updated_device_id',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
            'balance_kurus' => 'integer',
            'updated_occurred_at' => 'datetime',
            'deleted_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    /** @return HasMany<CustomerPhone, $this> */
    public function phones(): HasMany
    {
        return $this->hasMany(CustomerPhone::class);
    }

    /** @return HasMany<CustomerAddress, $this> */
    public function addresses(): HasMany
    {
        return $this->hasMany(CustomerAddress::class);
    }
}
