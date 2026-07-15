<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Defterin APPEND-ONLY kalbi (kırmızı çizgi #2). Silme/güncelleme yok; düzeltme ters kayıtla
 * (entry_type='correction', amount_kurus signed). customers.balance_kurus buradan türetilir.
 *
 * FAZ 2: şema + sync hattı hazır; defteri üreten iş akışları FAZ 3. Yalnız created_at (timestamps kapalı).
 *
 * @property string $id
 * @property string $tenant_id
 * @property string|null $customer_id
 * @property string $entry_type
 * @property int $amount_kurus
 * @property string|null $payment_type
 * @property string|null $collected_by_user_id
 * @property string|null $related_order_id
 * @property string|null $reverses_entry_id
 * @property string|null $note
 * @property Carbon $occurred_at
 * @property string|null $device_id
 * @property string $client_event_id
 * @property Carbon|null $created_at
 */
class LedgerEntry extends Model
{
    use HasUuids;

    public $timestamps = false; // yalnız created_at (DB useCurrent); updated_at yok — append-only

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'entry_type',
        'amount_kurus',
        'payment_type',
        'collected_by_user_id',
        'related_order_id',
        'reverses_entry_id',
        'note',
        'occurred_at',
        'device_id',
        'client_event_id',
    ];

    protected function casts(): array
    {
        return [
            'amount_kurus' => 'integer',
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
