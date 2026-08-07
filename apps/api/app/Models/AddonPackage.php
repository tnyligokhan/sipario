<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * Satıştaki ek paket (oto-sıralama hakkı veya ek kurye hesabı). Para İMZASIZ int KURUŞ.
 * Paket SİLİNMEZ, `active=false` ile satıştan çekilir — geçmiş tanımlamalar referanslıdır.
 *
 * @property string $id
 * @property string $type credits | courier
 * @property string $name
 * @property int $quantity
 * @property int $price_kurus
 * @property bool $active
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class AddonPackage extends Model
{
    use HasUuids;

    /** Kontör paketi: tenants.route_credits'i artırır. */
    public const TYPE_CREDITS = 'credits';

    /** Kurye paketi: tenants.courier_limit'i artırır. */
    public const TYPE_COURIER = 'courier';

    protected $fillable = [
        'type',
        'name',
        'quantity',
        'price_kurus',
        'active',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'price_kurus' => 'integer',
            'active' => 'boolean',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
        ];
    }

    /**
     * @param  Builder<AddonPackage>  $query
     * @return Builder<AddonPackage>
     */
    public function scopeSatista(Builder $query): Builder
    {
        return $query->where('active', true);
    }
}
