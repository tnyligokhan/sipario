<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * İşletme profili — bayi başına TEK satır (tasarım: "İşletme Profili"). Birincil anahtar tenant_id'dir
 * (surrogate uuid yok): iki cihazın çevrimdışı yazımı aynı satırda LWW ile birleşir, çakışıp
 * reddedilemez. Bu yüzden HasUuids KULLANILMAZ ve $incrementing kapalıdır.
 *
 * Firma kodu burada değildir — o `tenants.slug`'tur (sunucu sahipli, istemci yazamaz).
 *
 * @property string $tenant_id
 * @property string|null $business_name
 * @property string|null $owner_name
 * @property string|null $phone
 * @property string|null $whatsapp
 * @property string|null $address_text
 * @property string|null $tax_office
 * @property string|null $tax_number
 * @property string|null $opens_at
 * @property string|null $closes_at
 * @property string|null $receipt_note
 * @property string $order_code_display  'musteri' | 'siparis' — sipariş satırında hangi kod görünür
 * @property Carbon $updated_occurred_at
 * @property string|null $updated_device_id
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class TenantSetting extends Model
{
    protected $primaryKey = 'tenant_id';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'tenant_id',
        'business_name',
        'owner_name',
        'phone',
        'whatsapp',
        'address_text',
        'tax_office',
        'tax_number',
        'opens_at',
        'closes_at',
        'receipt_note',
        'order_code_display',
        'updated_occurred_at',
        'updated_device_id',
    ];

    protected function casts(): array
    {
        return [
            'updated_occurred_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }
}
