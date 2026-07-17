<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Kupon hareketi — APPEND-ONLY (kırmızı çizgi #2, ledger_entries kalıbı). Kupon PARA değil ADETtir:
 * qty_delta İMZALI (grant +N, use −qty, correction imzalı). Silme/güncelleme yok; düzeltme yalnız
 * ters hareketle (movement_type='correction', reverses_movement_id). coupon_balances buradan türetilir.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $customer_id
 * @property string|null $product_id
 * @property string $movement_type
 * @property int $qty_delta
 * @property string|null $related_order_id
 * @property string|null $note
 * @property string|null $reverses_movement_id
 * @property Carbon $occurred_at
 * @property string|null $device_id
 * @property string $client_event_id
 * @property Carbon|null $created_at
 */
class CouponMovement extends Model
{
    use HasUuids;

    public $timestamps = false; // yalnız created_at (DB useCurrent); updated_at yok — append-only

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'product_id',
        'movement_type',
        'qty_delta',
        'related_order_id',
        'note',
        'reverses_movement_id',
        'occurred_at',
        'device_id',
        'client_event_id',
    ];

    protected function casts(): array
    {
        return [
            'qty_delta' => 'integer',
            'occurred_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Customer, $this> */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }
}
