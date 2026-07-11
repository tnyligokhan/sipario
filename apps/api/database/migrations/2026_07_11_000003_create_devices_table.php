<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * devices — bayinin cihazları. id İSTEMCİDE üretilir (offline-first): cihaz kendi UUIDv7'sini
 * gönderir, sunucu korur. RLS 2026_07_11_130000'de etkinleşir.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('devices', function (Blueprint $table) {
            $table->uuid('id')->primary();                    // istemci üretimli device_id
            $table->uuid('tenant_id');
            $table->uuid('user_id')->nullable();              // cihazı kaydeden kullanıcı
            $table->string('platform', 20);                   // android|ios (CHECK aşağıda)
            $table->string('model', 120)->nullable();
            $table->string('os_version', 60)->nullable();
            $table->string('app_version', 40)->nullable();
            $table->string('push_token', 255)->nullable();
            $table->timestampTz('last_seen_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->nullOnDelete();
            $table->index('tenant_id');
            $table->index(['tenant_id', 'user_id']);
        });

        DB::statement(
            'ALTER TABLE devices ADD CONSTRAINT devices_platform_check '.
            "CHECK (platform IN ('android','ios'))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('devices');
    }
};
