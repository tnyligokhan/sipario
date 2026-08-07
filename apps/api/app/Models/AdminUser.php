<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Support\Carbon;

/**
 * Yönetim paneli hesabı (Faz 5c). BİZE aittir; bayilerin `users` tablosundan TAMAMEN ayrıdır
 * (TENANT YOK, RLS YOK). Email GLOBAL tekil. Rol: superadmin | support.
 *
 * `pgsql_panel` bağlantısı üzerinden yaşar (sipario_panel rolü — BYPASSRLS cross-tenant okur ama iş
 * verisine yazamaz). Panel `admin` guard'ı bu modeli kullanır. Kimlik UUIDv7; parola bcrypt.
 *
 * @property string $id
 * @property string $name
 * @property string $email
 * @property string $password
 * @property string $role
 * @property Carbon|null $disabled_at
 * @property Carbon|null $last_login_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class AdminUser extends Authenticatable
{
    use HasUuids;

    /** Panel modelleri BYPASSRLS panel rolüyle konuşur (iş verisine yazamaz; admin_users'a yazar). */
    protected $connection = 'pgsql_panel';

    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'last_login_at',
        'disabled_at',
    ];

    protected $hidden = [
        'password',
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'last_login_at' => 'datetime',
            'disabled_at' => 'datetime',
        ];
    }

    /**
     * PASİF HESAPLAR VARSAYILAN OLARAK GÖRÜNMEZ (5c-3 · D5) ve bu bilinçli olarak MODEL düzeyindedir.
     *
     * `admin` guard bu modeli kullanır: hem `retrieveByCredentials` (giriş denemesi) hem
     * `retrieveById` (her istekte oturumun çözülmesi) bu sorgudan geçer. Kapsam burada olunca
     * pasifleştirilen hesap yalnız giremez değil, AÇIK OTURUMU DA anında çalışmaz olur —
     * kontrolü giriş ekranına koysaydık pasifleştirilen kişi tarayıcısı açıkken çalışmayı
     * sürdürürdü ve "pasifleştirdim" demek yanlış olurdu.
     *
     * Yönetim ekranı listeyi `withoutGlobalScope('aktif')` ile çeker — orada pasifler görünmeli.
     */
    protected static function booted(): void
    {
        static::addGlobalScope('aktif', function (Builder $query): void {
            $query->whereNull('disabled_at');
        });
    }

    public function isSuperadmin(): bool
    {
        return $this->role === 'superadmin';
    }

    public function pasifMi(): bool
    {
        return $this->disabled_at !== null;
    }
}
