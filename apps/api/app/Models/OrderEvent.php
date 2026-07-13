<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Siparişin OLAY defteri (DECISIONS: orders.status/total önbellek, kaynak burası). APPEND-ONLY:
 * bu modelde update/delete yolu kullanılmaz. Yalnız created_at vardır (updated_at yok → timestamps kapalı).
 * created_at DB tarafında useCurrent ile dolar. RLS: tenant_id policy'sine tabidir.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $order_id
 * @property string $event_type
 * @property array<string, mixed>|null $payload
 * @property string $client_event_id
 * @property Carbon $occurred_at
 * @property string|null $device_id
 * @property Carbon|null $created_at
 */
class OrderEvent extends Model
{
    use HasUuids;

    public $timestamps = false; // yalnız created_at (DB useCurrent); updated_at yok

    protected $fillable = [
        'id',
        'tenant_id',
        'order_id',
        'event_type',
        'payload',
        'client_event_id',
        'occurred_at',
        'device_id',
    ];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'occurred_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Order, $this> */
    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }
}
