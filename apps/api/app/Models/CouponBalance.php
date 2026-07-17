<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Kupon bakiyesi ÖNBELLEĞİ (customers.balance_kurus ikizi). balance_qty = SUM(qty_delta) coupon_
 * movements'ten türetilir; UPDATE'lenir (append DEĞİL), bozulursa hareketlerden yeniden kurulur.
 * Eksiye düşebilir (KABUL — teslim edilmiş mal gerçektir). timestamps yok.
 *
 * Surrogate uuid id yalnız sync_changes.entity_id içindir; iş anahtarı (tenant_id, customer_id,
 * product_id). product_id NULL = genel kupon (UNIQUE NULLS NOT DISTINCT).
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $customer_id
 * @property string|null $product_id
 * @property int $balance_qty
 */
class CouponBalance extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'product_id',
        'balance_qty',
    ];

    protected function casts(): array
    {
        return [
            'balance_qty' => 'integer',
        ];
    }

    /** @return BelongsTo<Customer, $this> */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }
}
