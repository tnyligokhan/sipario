<?php

namespace App\Support;

use App\Enums\TenantStatus;
use App\Enums\UserRole;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Bayi provizyonu (hesap açma). Bu işlemler RLS'i MEŞRU olarak atlar: yeni bir tenant satırı
 * eklemek yumurta-tavuk sorunudur (tenants WITH CHECK, app.tenant_id = eklenen id ister) ve
 * hesap açma zaten kiracı-üstü bir eylemdir. Bu yüzden owner (pgsql_owner) bağlantısı kullanılır.
 *
 * Testlerdeki iki-tenant seed helper'ı da bu deseni kullanabilir: provizyon owner ile, ASIL
 * test istekleri app rolü token'larıyla (RLS'e tabi).
 */
class Provisioning
{
    /**
     * Provizyon işini owner bağlantısında koşar (varsayılan bağlantıyı geçici olarak değiştirir).
     *
     * @template T
     *
     * @param  callable():T  $callback
     * @return T
     */
    public static function asOwner(callable $callback): mixed
    {
        $previous = DB::getDefaultConnection();
        DB::setDefaultConnection('pgsql_owner');

        try {
            return $callback();
        } finally {
            DB::setDefaultConnection($previous);
        }
    }

    /**
     * Yeni bir bayi + patron kullanıcı oluşturur (30 gün deneme).
     *
     * @return array{tenant: Tenant, patron: User}
     */
    public static function createTenantWithPatron(
        string $tenantName,
        string $patronEmail,
        string $patronPassword,
        string $patronName = 'Patron',
    ): array {
        return self::asOwner(function () use ($tenantName, $patronEmail, $patronPassword, $patronName) {
            $tenant = Tenant::create([
                'name' => $tenantName,
                'status' => TenantStatus::Trial->value,
                'trial_ends_at' => now()->addDays(30),
            ]);

            $patron = User::create([
                'tenant_id' => $tenant->id,
                'name' => $patronName,
                'email' => mb_strtolower($patronEmail),
                'password' => $patronPassword, // 'hashed' cast'i bcrypt'ler
                'role' => UserRole::Patron->value,
                'status' => 'active',
            ]);

            return ['tenant' => $tenant, 'patron' => $patron];
        });
    }
}
