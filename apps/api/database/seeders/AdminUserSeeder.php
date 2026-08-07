<?php

namespace Database\Seeders;

use App\Models\AdminUser;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
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
}
