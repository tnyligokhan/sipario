<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 5c — yönetim paneli kullanıcıları (DECISIONS "Faz 5 — mimari"). Panel BİZE aittir; admin_users
 * bayilerin `users` tablosundan TAMAMEN ayrıdır (TENANT YOK, RLS YOK — panel altyapısı, tıpkı
 * personal_access_tokens gibi). Email GLOBAL tekil. Rol: superadmin | support.
 *
 * Kimlik UUIDv7. Parola bcrypt (model cast'i). Panel ayrı `admin` guard + `pgsql_panel` bağlantısıyla
 * yönetilir (sipario_panel bu tabloya SELECT/INSERT/UPDATE grant'ine sahip — migration 000504).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->string('role', 20)->default('support'); // superadmin | support
            $table->timestampTz('last_login_at')->nullable();
            $table->timestampsTz();
        });

        DB::statement(
            'ALTER TABLE admin_users ADD CONSTRAINT admin_users_role_check '.
            "CHECK (role IN ('superadmin','support'))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_users');
    }
};
