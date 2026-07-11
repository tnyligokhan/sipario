<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * users — bir tenant'a bağlı kullanıcılar (patron/operator/kurye).
 * (Laravel iskeletindeki 0001_01_01_000000 users migration'ının yerini alır; tenants'a FK
 * verdiği için tenants'tan SONRA koşmak zorunda — bu yüzden 2026_07_11 tarih bandında.)
 * Ayrıca session ve parola-sıfırlama tablolarını da burada tutuyoruz (Livewire paneli Faz 5).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();                       // UUIDv7
            $table->uuid('tenant_id');
            $table->string('name', 120);
            // Email GLOBAL tekil: login yalnız email+parola alır (mobilde tenant kodu yok),
            // lookup deterministik tek satır dönsün. Küçük harfe normalize edilir.
            $table->string('email', 190)->unique();
            $table->string('password');                          // bcrypt
            $table->string('role', 20);                          // patron|operator|kurye (CHECK aşağıda)
            $table->string('status', 20)->default('active');     // active|disabled
            $table->string('phone', 20)->nullable();
            $table->timestampTz('last_login_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->index('tenant_id');
            // Faz 2 bileşik yabancı anahtarı için: FOREIGN KEY (tenant_id,user_id)
            //   REFERENCES users(tenant_id,id) kurulabilsin.
            $table->unique(['tenant_id', 'id']);
        });

        DB::statement(
            'ALTER TABLE users ADD CONSTRAINT users_role_check '.
            "CHECK (role IN ('patron','operator','kurye'))"
        );
        DB::statement(
            'ALTER TABLE users ADD CONSTRAINT users_status_check '.
            "CHECK (status IN ('active','disabled'))"
        );

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestampTz('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->uuid('user_id')->nullable()->index();   // Faz 5 panel; FK'siz (RLS yok)
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('users');
    }
};
