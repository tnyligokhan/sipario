<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Muaf telefon — bu numara aradığında arayan tanıma kartı GÖSTERİLMEZ (tasarım: "Muaf Telefonlar").
 * phone_last10 customer_phones ile aynı eşleşme anahtarıdır; native taraf kart çizmeden önce bakar.
 * Standart LWW + tombstone varlığı (para kaydı değil).
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $phone_e164
 * @property string $phone_last10
 * @property string|null $label
 * @property Carbon $updated_occurred_at
 * @property string|null $updated_device_id
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class ExemptNumber extends Model
{
    use HasUuids, MikrosaniyeliDamga;

    protected $fillable = [
        'id',
        'tenant_id',
        'phone_e164',
        'phone_last10',
        'label',
        'updated_occurred_at',
        'updated_device_id',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
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
