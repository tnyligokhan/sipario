<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * Abonelik planı — TEK satır (DB'de `plans_single_row` tekil indeksiyle zorlanır). Panelden
 * düzenlenir, site/checkout buradan okur (App\Abonelik\PlanDeposu). Para İMZASIZ int KURUŞ.
 *
 * `created_at` YOKtur (tek satır hiç yaratılmaz, hep güncellenir) → CREATED_AT = null; `updated_at`
 * Eloquent tarafından yönetilmeye devam eder.
 *
 * @property string $id
 * @property string $name
 * @property int $price_monthly_kurus
 * @property int $price_yearly_kurus
 * @property int $trial_days
 * @property int $route_credits_monthly
 * @property int $courier_limit
 * @property Carbon|null $updated_at
 */
class Plan extends Model
{
    use HasUuids;

    public const CREATED_AT = null;

    protected $fillable = [
        'name',
        'price_monthly_kurus',
        'price_yearly_kurus',
        'trial_days',
        'route_credits_monthly',
        'courier_limit',
    ];

    protected function casts(): array
    {
        return [
            'price_monthly_kurus' => 'integer',
            'price_yearly_kurus' => 'integer',
            'trial_days' => 'integer',
            'route_credits_monthly' => 'integer',
            'courier_limit' => 'integer',
            'updated_at' => 'datetime',
        ];
    }
}
