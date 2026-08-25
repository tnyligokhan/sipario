<?php

namespace App\Models;

use App\Support\SiraKodu;
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
 * @property int|null $code
 * @property string|null $assigned_user_id
 * @property string|null $delivered_by_user_id
 * @property string $status
 * @property int $total_kurus
 * @property string|null $payment_type
 * @property string|null $note
 * @property int|null $sort_index
 * @property Carbon $occurred_at
 * @property string|null $created_device_id
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class Order extends Model
{
    use HasUuids, MikrosaniyeliDamga;

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'code',
        'assigned_user_id',
        // TESLİMİ KİM YAPTI — atamanın (niyet) yanındaki OLGU. Önbellektir, kaynağı `delivered`
        // olayının payload'ıdır; `recomputeOrder` türetir (migration 004016).
        'delivered_by_user_id',
        'status',
        'total_kurus',
        'payment_type',
        'note',
        'sort_index',
        'occurred_at',
        'created_device_id',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
            'code' => 'integer',
            'total_kurus' => 'integer',
            'sort_index' => 'integer',
            'occurred_at' => 'datetime',
            'deleted_at' => 'datetime',
        ];
    }

    /**
     * Sipariş kodu (#248) MODEL DÜZEYİNDE atanır — gerekçesi `Customer::booted` ile aynı:
     * sipariş senkron dışında da doğuyor (demo seeder) ve kodsuz bir sipariş yalnız sahada
     * fark edilirdi. İstemci kod GÖNDEREMEZ; `OrderChangeApplier` yazılabilir kolonlar
     * listesinde yoktur (aynı `balance_kurus` deseni).
     */
    protected static function booted(): void
    {
        static::creating(function (self $m): void {
            $m->code ??= SiraKodu::sonraki('orders', $m->tenant_id);
        });
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
