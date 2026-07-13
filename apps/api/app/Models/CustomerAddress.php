<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Müşterinin adresi (ev/işyeri). lat/lng opsiyonel (konum yoksa teslim bloklanmaz — BRIEF).
 * RLS: tenant_id policy'sine tabidir. LWW meta + tombstone.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $customer_id
 * @property string|null $label
 * @property string $address_text
 * @property float|null $lat
 * @property float|null $lng
 * @property bool $is_primary
 * @property Carbon $updated_occurred_at
 * @property string|null $updated_device_id
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class CustomerAddress extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'label',
        'address_text',
        'lat',
        'lng',
        'is_primary',
        'updated_occurred_at',
        'updated_device_id',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
            'lat' => 'float',
            'lng' => 'float',
            'is_primary' => 'boolean',
            'updated_occurred_at' => 'datetime',
            'deleted_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Customer, $this> */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }
}
