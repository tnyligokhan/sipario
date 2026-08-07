<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Bayinin siteden yaptığı "havale gönderdim" BEYANI. Bir İDDİAdır, para kaydı DEĞİLDİR — aboneliği
 * uzatmaz. Panelden eşleştirilince gerçek `subscription_payments` satırı doğar ve buraya bağlanır.
 *
 * Durum makinesi: pending → matched | rejected (tek yönlü; kapanmış bildirim yeniden açılmaz).
 *
 * @property string $id
 * @property string $tenant_id
 * @property int $amount_kurus
 * @property string $method iban | elden
 * @property string $reference_code
 * @property Carbon $declared_on
 * @property string $status pending | matched | rejected
 * @property string|null $subscription_payment_id
 * @property string|null $note
 * @property string|null $consent_version
 * @property Carbon|null $consented_at
 * @property Carbon|null $created_at
 * @property Carbon|null $resolved_at
 * @property string|null $resolved_by_admin_id
 */
class PaymentNotification extends Model
{
    use HasUuids;

    public $timestamps = false; // created_at DB useCurrent; resolved_at elle yazılır

    public const STATUS_PENDING = 'pending';

    public const STATUS_MATCHED = 'matched';

    public const STATUS_REJECTED = 'rejected';

    protected $fillable = [
        'id',
        'tenant_id',
        'amount_kurus',
        'method',
        'reference_code',
        'declared_on',
        'status',
        'subscription_payment_id',
        'note',
        // Hukuki onay — subscription_payments'takiyle BİREBİR aynı çift (005012).
        'consent_version',
        'consented_at',
        'resolved_at',
        'resolved_by_admin_id',
    ];

    protected function casts(): array
    {
        return [
            'amount_kurus' => 'integer',
            'declared_on' => 'date',
            'consented_at' => 'datetime',
            'created_at' => 'datetime',
            'resolved_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    /** @return BelongsTo<SubscriptionPayment, $this> */
    public function payment(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPayment::class, 'subscription_payment_id');
    }
}
