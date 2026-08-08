<?php

use App\Models\AdminUser;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * Yönetici paneli hesaplarının (gokhan@sipario.com.tr ve bugra@sipario.com.tr)
 * veritabanına otomatik eklenmesini sağlayan migration.
 */
return new class extends Migration {
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        $password = Hash::make('SiparioAdmin2026!');

        AdminUser::withoutGlobalScope('aktif')->updateOrCreate(
            ['email' => 'gokhan@sipario.com.tr'],
            [
                'name' => 'Gökhan',
                'password' => $password,
                'role' => 'superadmin',
                'disabled_at' => null,
            ]
        );

        AdminUser::withoutGlobalScope('aktif')->updateOrCreate(
            ['email' => 'bugra@sipario.com.tr'],
            [
                'name' => 'Buğra',
                'password' => $password,
                'role' => 'superadmin',
                'disabled_at' => null,
            ]
        );
    }

    public function down(): void
    {
    }
};
