<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Kasa devri — APPEND-ONLY kalıcı mutabakat kaydı (kırmızı çizgi #2, ledger_entries kalıbı). Kurye gün
 * sonu kasayı patrona devreder. counted_cash_kurus (sayılan) − expected_cash_kurus (beklenen, anlık
 * snapshot) = diff_kurus; fark KANIT olarak durur. Silme/güncelleme yok; düzeltme yeni devir kaydıyla.
 *
 * Kimlik istemcide UUIDv7 (offline-first). Yalnız INSERT edilir (timestamps sadece oluşturmada dolar).
 *
 * reverses_handover_id (2026-08-13): İPTAL EDİLEN devir. İptal bir silme değil, TERS BİR SATIRdır
 * (counted negatif, expected/diff sıfır) — `LedgerEntry::reverses_entry_id` ile aynı desen. Bir devir
 * en fazla bir kez iptal edilebilir; tekillik kısmi unique indeksle (migration 004011) DB'de zorlanır.
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $from_user_id
 * @property string|null $reverses_handover_id
 * @property string|null $to_user_id
 * @property int $counted_cash_kurus
 * @property int $expected_cash_kurus
 * @property int $diff_kurus
 * @property Carbon|null $period_start
 * @property Carbon $occurred_at
 * @property string|null $device_id
 * @property string|null $note
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class CashHandover extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'tenant_id',
        'from_user_id',
        'to_user_id',
        'reverses_handover_id',
        'counted_cash_kurus',
        'expected_cash_kurus',
        'diff_kurus',
        'period_start',
        'occurred_at',
        'device_id',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'counted_cash_kurus' => 'integer',
            'expected_cash_kurus' => 'integer',
            'diff_kurus' => 'integer',
            'period_start' => 'datetime',
            'occurred_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<User, $this> */
    public function fromUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'from_user_id');
    }
}
