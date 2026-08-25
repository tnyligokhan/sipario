<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Gün sonu kapanış arşivi — APPEND-ONLY (kırmızı çizgi #2, cash_handovers kalıbı). scope: day|courier.
 * Özet alanları kapatıldığı ANDAKİ gerçeği taşır (order_lines.unit_price deseni): sonradan gelen geç
 * senkron bugünün toplamını değiştirse de arşiv değişmez. diff_kurus fark KANITIdır.
 *
 * Kimlik istemcide UUIDv7 (offline-first). Yalnız INSERT edilir.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $scope
 * @property string|null $user_id
 * @property string|null $reverses_closing_id
 * @property Carbon|null $period_start
 * @property int $delivery_count
 * @property int $total_collected_kurus
 * @property int $cash_nakit_kurus
 * @property int $cash_kart_kurus
 * @property int $cash_havale_kurus
 * @property int $open_credit_kurus
 * @property int $expected_cash_kurus
 * @property int|null $counted_cash_kurus
 * @property int $diff_kurus
 * @property string|null $cash_handover_id
 * @property string|null $note
 * @property Carbon $occurred_at
 * @property string|null $device_id
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class DayClosing extends Model
{
    use HasUuids, MikrosaniyeliDamga;

    protected $fillable = [
        'id',
        'tenant_id',
        'scope',
        'user_id',
        'reverses_closing_id',
        'period_start',
        'delivery_count',
        'total_collected_kurus',
        'cash_nakit_kurus',
        'cash_kart_kurus',
        'cash_havale_kurus',
        'open_credit_kurus',
        'expected_cash_kurus',
        'counted_cash_kurus',
        'diff_kurus',
        'cash_handover_id',
        'note',
        'occurred_at',
        'device_id',
    ];

    protected function casts(): array
    {
        return [
            'period_start' => 'datetime',
            'occurred_at' => 'datetime',
            'delivery_count' => 'integer',
            'total_collected_kurus' => 'integer',
            'cash_nakit_kurus' => 'integer',
            'cash_kart_kurus' => 'integer',
            'cash_havale_kurus' => 'integer',
            'open_credit_kurus' => 'integer',
            'expected_cash_kurus' => 'integer',
            'counted_cash_kurus' => 'integer',
            'diff_kurus' => 'integer',
        ];
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
