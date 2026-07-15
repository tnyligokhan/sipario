<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * Abonelik ödemesi — APPEND-ONLY denetim kaydı (FAZ 5b, ledger_entries kalıbı). Her girişim/sonuç ayrı
 * satır (initiated/success/failed); durum UPDATE'lenmez. Para İMZASIZ int KURUŞ. Kart verisi YOK (KVKK).
 *
 * Kimlik UUIDv7. Yalnız created_at (append; updated_at yok). Yazımlar aktivasyon akışında owner ile.
 *
 * @property string $id
 * @property string $tenant_id
 * @property int $amount_kurus
 * @property string $currency
 * @property string $provider
 * @property string $provider_ref
 * @property string $status
 * @property string|null $consent_version
 * @property Carbon|null $consented_at
 * @property Carbon $occurred_at
 * @property Carbon|null $created_at
 */
class SubscriptionPayment extends Model
{
    use HasUuids;

    public $timestamps = false; // yalnız created_at (DB useCurrent); append-only

    protected $fillable = [
        'id',
        'tenant_id',
        'amount_kurus',
        'currency',
        'provider',
        'provider_ref',
        'status',
        'consent_version',
        'consented_at',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return [
            'amount_kurus' => 'integer',
            'consented_at' => 'datetime',
            'occurred_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }
}
