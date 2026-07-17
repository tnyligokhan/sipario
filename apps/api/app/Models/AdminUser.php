<?php

namespace App\Models;

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
    ];

    protected $hidden = [
        'password',
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'last_login_at' => 'datetime',
        ];
    }

    public function isSuperadmin(): bool
    {
        return $this->role === 'superadmin';
    }
}
