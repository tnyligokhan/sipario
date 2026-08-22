<?php

namespace App\Models;

use App\Enums\UserRole;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\HasApiTokens;

/**
 * Bir bayiye (tenant) bağlı kullanıcı: patron / operator / kurye.
 * Kimlik UUIDv7. Kimlik doğrulama Sanctum token'ı ile (session yok → remember_token yok).
 * RLS: bu tablo tenant_id policy'sine tabidir; bir bayi diğerinin kullanıcısını göremez.
 *
 * casts() ile türeyen gerçek tipler (statik analiz bunları kolon şemasından çıkaramaz):
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $name
 * @property string $email
 * @property string $username
 * @property string $password
 * @property UserRole $role
 * @property string $status
 * @property string|null $phone
 * @property Carbon|null $last_login_at
 * @property Carbon|null $updated_occurred_at
 * @property string|null $updated_device_id
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * @property bool|null $courier_can_customers
 * @property bool|null $courier_can_orders
 * @property bool|null $courier_can_collect
 * @property bool|null $courier_can_discount
 * @property bool|null $courier_can_day_end
 * @property bool|null $courier_can_see_all_orders
 * @property bool|null $courier_can_view_history
 * @property bool|null $courier_can_expense
 * @property bool|null $courier_phone_mask
 * @property bool|null $courier_can_customer_ledger
 * @property bool|null $courier_can_debt_reminder
 * @property bool|null $courier_can_toggle_stock
 * @property bool|null $courier_can_call_log
 * @property bool|null $courier_can_see_all_customers
 */
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, HasUuids, MikrosaniyeliDamga, Notifiable;

    protected $fillable = [
        'tenant_id',
        'name',
        'email',
        // Tasarım `s-giris.jsx`: mobil giriş firma kodu + KULLANICI ADI ile yapılır.
        // Tenant içinde tekildir (global değil) — ayrımı firma kodu yapar.
        'username',
        'password',
        'role',
        'status',
        'phone',
        'last_login_at',
        'updated_occurred_at',
        'updated_device_id',
        // KİŞİYE ÖZEL KURYE YETKİLERİ BİLEREK BURADA YOK (2026-08-10). Yetki kolonları TOPLU
        // ATAMAYLA yazılamaz: tek meşru yazma yolu `ProfileChangeApplier::applyUserProfile`tir ve
        // orası `forceFill` kullanır (fillable'a bakmaz) — ayrıca yetki yükseltme kapısı oradadır.
        // Listeye eklemek, ileride bir form/istek dizisini `fill()`e veren herhangi bir yüzeye
        // kapıyı ATLAYARAK yetki yazdırırdı; `$fillable`ın var oluş sebebi tam olarak budur.
    ];

    protected $hidden = [
        'password',
    ];

    /**
     * KİŞİYE ÖZEL kurye yetki kolonları — 3 durumlu DEVRALMA (kullanıcı kararı 2026-08-10,
     * migration 004008).
     *
     *   NULL  → bayi varsayılanını devral (`tenant_settings.courier_x`)
     *   true  → kişiye özel AÇIK
     *   false → kişiye özel KAPALI
     *
     * Etkin yetki = `users.courier_x ?? tenant_settings.courier_x`. Birleştirme İSTEMCİDE yapılır:
     * `team` bloğu kişisel değeri, `tenant_settings` bayi varsayılanını taşır — sunucu ikisini
     * birleştirip yayınlasaydı değer hangi katmandan geldiğini kaybederdi ve "devralıyor" ile
     * "kişiye özel açık" bir daha ayırt edilemezdi (yetki ekranı tam bu ayrımı gösterir).
     *
     * LİSTE BURADA SAYILMAZ, `TenantSetting::KURYE_IZINLERI`'nden TÜRETİLİR: tek doğru yer odur
     * (varsayılanlarıyla birlikte). Burada yalnız anahtarları ödünç alınır — "varsayılan" kavramı
     * bu tarafta yoktur, NULL vardır. Elle kopyalanan ikinci bir liste er geç ıraksardı ve ıraksama
     * sessizdir: eksik kalan kolon hiç yazılmaz, hiç yayınlanmaz, hata da vermez.
     *
     * @return list<string>
     */
    public static function kuryeIzinKolonlari(): array
    {
        return array_keys(TenantSetting::KURYE_IZINLERI);
    }

    protected function casts(): array
    {
        // `boolean` cast NULL'ı NULL bırakır (Eloquent primitif cast'leri null'ı dönüştürmez) —
        // "devral" hâlinin `false`a çökmemesi tam buna dayanır.
        return array_fill_keys(self::kuryeIzinKolonlari(), 'boolean') + [
            'password' => 'hashed',
            'role' => UserRole::class,
            'last_login_at' => 'datetime',
            'updated_occurred_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }
}
