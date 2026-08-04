<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Bir bayiye ek paket TANIMLAMASI — APPEND-ONLY (UPDATE/DELETE yoktur; yanlış tanımlama yeni
 * kayıtla kapatılır). Paketin adı/türü/adedi satıra KOPYALANIR: paket bağı kopsa bile kayıt okunur.
 *
 * `collection_method='bedelsiz'` → `amount_kurus=0` (DB CHECK) ve gelir kaydı OLUŞMAZ.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string|null $addon_package_id
 * @property string $package_name
 * @property string $type credits | courier
 * @property int $quantity
 * @property int $amount_kurus
 * @property string $collection_method iban | elden | bedelsiz
 * @property Carbon $granted_on
 * @property string|null $note
 * @property string|null $admin_user_id
 * @property Carbon|null $created_at
 */
class AddonGrant extends Model
{
    use HasUuids;

    public $timestamps = false; // yalnız created_at (DB useCurrent); append-only

    protected $fillable = [
        'id',
        'tenant_id',
        'addon_package_id',
        'package_name',
        'type',
        'quantity',
        'amount_kurus',
        'collection_method',
        'granted_on',
        'note',
        'admin_user_id',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'amount_kurus' => 'integer',
            'granted_on' => 'date',
            'created_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    /** @return BelongsTo<AddonPackage, $this> */
    public function package(): BelongsTo
    {
        return $this->belongsTo(AddonPackage::class, 'addon_package_id');
    }
}
