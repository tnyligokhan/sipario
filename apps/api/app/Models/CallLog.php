<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Çağrı günlüğü (tasarım: "Son Aramalar"). direction: incoming|missed|outgoing.
 * APPEND-ONLY DEĞİL — outcome/customer_id çağrıdan sonra zenginleşir; para kaydı olmadığından
 * kırmızı çizgi #2 kapsamı dışında, standart LWW + tombstone varlığı.
 *
 * KVKK: numara TR sunucuda customer_phones ile aynı sınıftadır; log/crash raporuna ASLA yazılmaz.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string|null $customer_id
 * @property string $phone_e164
 * @property string $phone_last10
 * @property string $direction
 * @property string|null $outcome
 * @property string|null $related_order_id
 * @property Carbon $occurred_at
 * @property string|null $device_id
 * @property Carbon $updated_occurred_at
 * @property string|null $updated_device_id
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class CallLog extends Model
{
    use HasUuids, MikrosaniyeliDamga;

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'phone_e164',
        'phone_last10',
        'direction',
        'outcome',
        'related_order_id',
        'user_id',
        'occurred_at',
        'device_id',
        'updated_occurred_at',
        'updated_device_id',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
            'occurred_at' => 'datetime',
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
