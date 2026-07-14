<?php

namespace App\Models;

use Database\Factories\ProductFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Bayinin ürün kataloğu. unit_price_kurus bugünkü fiyat; siparişe düşen fiyat order_lines'ta ayrıca
 * saklanır (DECISIONS). RLS: tenant_id policy'sine tabidir. is_active ile pasifleme (silme yerine).
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $name
 * @property int $unit_price_kurus
 * @property string $unit
 * @property bool $is_active
 * @property Carbon $updated_occurred_at
 * @property string|null $updated_device_id
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class Product extends Model
{
    /** @use HasFactory<ProductFactory> */
    use HasFactory, HasUuids;

    protected $fillable = [
        'id',
        'tenant_id',
        'name',
        'unit_price_kurus',
        'unit',
        'is_active',
        'updated_occurred_at',
        'updated_device_id',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
            'unit_price_kurus' => 'integer',
            'is_active' => 'boolean',
            'updated_occurred_at' => 'datetime',
            'deleted_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }
}
