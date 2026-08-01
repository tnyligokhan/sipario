<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 5c-3 · D5 — panel hesabının PASİFLEŞTİRİLMESİ.
 *
 * Neden silme değil: `panel_audit` satırları `admin_user_id` taşır ve denetim günlüğünün "kim
 * yaptı" sütunu ayrılan bir çalışanla birlikte boşalmamalıdır. Hesap kapatılır, geçmişi durur.
 *
 * Yeni GRANT gerekmez: `sipario_panel` admin_users üzerinde zaten SELECT/INSERT/UPDATE'e sahiptir
 * (migration 504) — pasifleştirme bir UPDATE'tir. DELETE yetkisi yoktur ve verilmiyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admin_users', function (Blueprint $table) {
            $table->timestampTz('disabled_at')->nullable()->after('role');
        });
    }

    public function down(): void
    {
        Schema::table('admin_users', function (Blueprint $table) {
            $table->dropColumn('disabled_at');
        });
    }
};
