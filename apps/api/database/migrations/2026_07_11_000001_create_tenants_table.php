<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * tenants — bayi (kiracı) kök tablosu. Her iş verisi bir tenant'a bağlıdır.
 * RLS bu tabloda 2026_07_11_130000 migration'ında etkinleştirilir.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenants', function (Blueprint $table) {
            $table->uuid('id')->primary();            // UUIDv7, sunucu üretir
            $table->string('name', 160);
            $table->string('slug', 80)->nullable()->unique();
            $table->string('status', 20)->default('trial');
            $table->timestampTz('trial_ends_at')->nullable();   // 30 gün deneme
            $table->timestampTz('valid_until')->nullable();      // abonelik/deneme bitişi (Faz 5)
            $table->string('phone', 20)->nullable();
            $table->timestampsTz();
        });

        DB::statement(
            'ALTER TABLE tenants ADD CONSTRAINT tenants_status_check '.
            "CHECK (status IN ('trial','active','locked','suspended'))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('tenants');
    }
};
