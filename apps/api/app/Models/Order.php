<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * Sipariş başlığı. status ve total_kurus ÖNBELLEKtir (DECISIONS: kaynak order_events); sunucu
 * push'ta olaylardan türetir. RLS: tenant_id policy'sine tabidir. deleted_at tombstone.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string|null $customer_id
 * @property string $status
 * @property int $total_kurus
 * @property string|null $payment_type
 * @property string|null $note
 * @property Carbon $occurred_at
 * @property string|null $created_device_id
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class Order extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'status',
        'total_kurus',
        'payment_type',
        'note',
        'occurred_at',
        'created_device_id',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
            'total_kurus' => 'integer',
            'occurred_at' => 'datetime',
            'deleted_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Customer, $this> */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    /** @return HasMany<OrderLine, $this> */
    public function lines(): HasMany
    {
        return $this->hasMany(OrderLine::class);
    }

    /** @return HasMany<OrderEvent, $this> */
    public function events(): HasMany
    {
        return $this->hasMany(OrderEvent::class);
    }
}
