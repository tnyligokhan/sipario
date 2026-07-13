<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Müşterinin telefon numarası (ev/cep). phone_last10 arayan tanımanın eşleşme anahtarıdır.
 * RLS: tenant_id policy'sine tabidir. LWW meta + tombstone.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $customer_id
 * @property string $phone_e164
 * @property string $phone_last10
 * @property string|null $label
 * @property bool $is_primary
 * @property Carbon $updated_occurred_at
 * @property string|null $updated_device_id
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class CustomerPhone extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'phone_e164',
        'phone_last10',
        'label',
        'is_primary',
        'updated_occurred_at',
        'updated_device_id',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
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
