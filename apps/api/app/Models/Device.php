<?php

namespace App\Models;

use Database\Factories\DeviceFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Bayinin kullandığı fiziksel cihaz (telefon/tablet).
 * Kimlik (id) İSTEMCİDE üretilir (offline-first): cihaz kendi UUIDv7'sini gönderir, sunucu korur.
 * RLS: tenant_id policy'sine tabidir.
 */
class Device extends Model
{
    /** @use HasFactory<DeviceFactory> */
    use HasFactory, HasUuids;

    protected $fillable = [
        'id',
        'tenant_id',
        'user_id',
        'platform',
        'model',
        'os_version',
        'app_version',
        'push_token',
        'last_seen_at',
    ];

    protected function casts(): array
    {
        return [
            'last_seen_at' => 'datetime',
        ];
    }

    /**
     * `updateOrCreate` için nitelik kümesi — İKİ ÇAĞIRANIN ORTAK KAPISI (`DeviceController::store`
     * ve `AuthController::upsertDevice`).
     *
     * ⚠️ `push_token` ALANI GÖNDERİLMEDİYSE DOKUNULMAZ, `null` YAZILMAZ. Aradaki fark push
     * sisteminin yaşamıdır: FCM jetonu uygulama açılışında ASENKRON gelir (Play Services'ten
     * saniyeler sonra). Cihaz kaydı ondan önce koşarsa — ki normal akış budur — "alan yok"u
     * "alanı boşalt" saymak, her açılışta jetonu silerdi. Sonuç sessiz olurdu: hata çıkmaz,
     * yalnız bildirimler bir gün gelmemeye başlardı.
     *
     * Bu, `TenantSettingsRepository`de (2026-08-13) mobil tarafta çözülen "verilmedi ≠ boşalt"
     * probleminin sunucu tarafındaki ikizidir.
     *
     * @param  array<string, mixed>  $girdi  Doğrulanmış istek verisi.
     * @return array<string, mixed>
     */
    public static function kayitNitelikleri(User $sahip, array $girdi): array
    {
        $nitelikler = [
            'tenant_id' => $sahip->tenant_id,
            'user_id' => $sahip->id,
            'platform' => $girdi['platform'],
            'model' => $girdi['model'] ?? null,
            'os_version' => $girdi['os_version'] ?? null,
            'app_version' => $girdi['app_version'] ?? null,
            'last_seen_at' => now(),
        ];

        if (array_key_exists('push_token', $girdi)) {
            $nitelikler['push_token'] = $girdi['push_token'];
        }

        return $nitelikler;
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
