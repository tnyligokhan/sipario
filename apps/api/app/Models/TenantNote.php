<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Panelden bayiye tutulan satış/destek notu — APPEND-ONLY (tutanak düzenlenmez, yeni not yazılır).
 * Bayiye GÖSTERİLMEZ (sipario_app'in izni yok).
 *
 * @property string $id
 * @property string $tenant_id
 * @property string|null $admin_user_id
 * @property string $body
 * @property Carbon|null $created_at
 */
class TenantNote extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'id',
        'tenant_id',
        'admin_user_id',
        'body',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }
}
