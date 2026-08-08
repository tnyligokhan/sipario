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
 * @property string|null $iban Bayinin KENDİ hesabı — borç hatırlatma mesajında geçer
 * @property string|null $iban_owner_name Hesap sahibinin ad soyadı; boşsa istemci işletme adına düşer
 * @property string|null $reminder_template Bayinin kendi hatırlatma metni; null = varsayılan (istemcide)
 * @property bool $courier_can_customers
 * @property bool $courier_can_orders
 * @property bool $courier_can_collect
 * @property bool $courier_can_discount
 * @property bool $courier_can_day_end
 * @property string $order_code_display 'musteri' | 'siparis' — sipariş satırında hangi kod görünür
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
        'iban',
        'iban_owner_name',
        'reminder_template',
        'courier_can_customers',
        'courier_can_orders',
        'courier_can_collect',
        'courier_can_discount',
        'courier_can_day_end',
        'courier_can_see_all_orders',
        'courier_can_view_history',
        'courier_can_expense',
        'courier_phone_mask',
        'courier_can_customer_ledger',
        'courier_can_debt_reminder',
        'courier_can_toggle_stock',
        'courier_can_call_log',
        'order_code_display',
        'updated_occurred_at',
        'updated_device_id',
    ];

    /**
     * Bayinin açıp kapatabildiği kurye yetkileri → varsayılan (Genel Yetki Matrisi).
     * Uygulayıcı bu diziyi dolaşır; yeni bir yetki eklendiğinde TEK yer değişir.
     *
     * @var array<string, bool>
     */
    public const KURYE_IZINLERI = [
        'courier_can_customers' => true,
        'courier_can_orders' => true,
        'courier_can_collect' => true,
        'courier_can_discount' => false,
        'courier_can_day_end' => false,
        'courier_can_see_all_orders' => false,
        'courier_can_view_history' => false,
        'courier_can_expense' => false,
        'courier_phone_mask' => true,
        'courier_can_customer_ledger' => false,
        'courier_can_debt_reminder' => false,
        'courier_can_toggle_stock' => true,
        'courier_can_call_log' => false,
    ];

    protected function casts(): array
    {
        return [
            'updated_occurred_at' => 'datetime',
            'courier_can_customers' => 'boolean',
            'courier_can_orders' => 'boolean',
            'courier_can_collect' => 'boolean',
            'courier_can_discount' => 'boolean',
            'courier_can_day_end' => 'boolean',
            'courier_can_see_all_orders' => 'boolean',
            'courier_can_view_history' => 'boolean',
            'courier_can_expense' => 'boolean',
            'courier_phone_mask' => 'boolean',
            'courier_can_customer_ledger' => 'boolean',
            'courier_can_debt_reminder' => 'boolean',
            'courier_can_toggle_stock' => 'boolean',
            'courier_can_call_log' => 'boolean',
        ];
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }
}
