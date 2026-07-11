<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * personal_access_tokens.tenant_id — middleware, kullanıcıyı YÜKLEMEDEN önce token satırından
 * tenant'ı okuyup app.tenant_id'yi set edebilsin diye (yumurta-tavuk çözümü, bkz. ResolveTenantContext).
 * Bu tablo tenant RLS'ine TABİ DEĞİLDİR (auth altyapısı; token hash'i zaten tahmin edilemez sır).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->uuid('tenant_id')->nullable()->after('tokenable_id')->index();
        });
    }

    public function down(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->dropIndex(['tenant_id']);
            $table->dropColumn('tenant_id');
        });
    }
};
