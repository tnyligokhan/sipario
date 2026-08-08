<?php

use Database\Seeders\DemoSeeder;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

/**
 * Gerçek doldurulmuş demo bayisinin (demo@sipario.com.tr)
 * veritabanına otomatik eklenmesini sağlayan migration.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        Artisan::call('db:seed', [
            '--class' => DemoSeeder::class,
            '--force' => true,
        ]);
    }

    public function down(): void
    {
    }
};
