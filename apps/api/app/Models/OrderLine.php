<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Sipariş satırı. product_name ve unit_price_kurus SATIRDA saklanır (DECISIONS: siparişin çekildiği
 * andaki gerçek). product_id yumuşak referans (FK yok). RLS: tenant_id policy'sine tabidir.
 *
 * note SATIR NOTUdur ("buzlu olsun") — siparişin tamamına ait `orders.note`tan AYRIDIR; ikisi
 * farklı sorulara cevap verir ve tek metinde eritilemez.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $order_id
 * @property string|null $product_id
 * @property string $product_name
 * @property int $unit_price_kurus
 * @property string|null $unit
 * @property string|null $note
 * @property bool $is_custom
 * @property int $qty
 * @property int $line_total_kurus
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class OrderLine extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'tenant_id',
        'order_id',
        'product_id',
        'product_name',
        'unit_price_kurus',
        'unit',
        'note',
        'options',
        'is_custom',
        'qty',
        'line_total_kurus',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
            'unit_price_kurus' => 'integer',
            'is_custom' => 'boolean',
            'options' => 'array',
            'qty' => 'integer',
            'line_total_kurus' => 'integer',
            'deleted_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Order, $this> */
    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }
}
