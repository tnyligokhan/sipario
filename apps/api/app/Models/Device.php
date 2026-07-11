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
