<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 5c-2 — opsiyonel modül bayrakları (BRIEF: boş/emanet takibi bayiden bayiye değişir; istemeyen
 * bayide o alanlar HİÇ görünmez). tenants += modules JSONB (ör. {"empty_tracking": false}). Panel
 * açar/kapar (tenants UPDATE grant'i var, 5c-1); istemci bayrağı subscription bloğu ile pull eder →
 * UI'yı ona göre çizer (mobil UI sonraki iş; sunucu + panel BU turda).
 *
 * RLS politikasını DEĞİŞTİRMEZ (tenant_id ayrımlayıcısı aynı). Varsayılan boş obje → hiçbir modül açık değil.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->jsonb('modules')->default('{}');
        });
    }

    public function down(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->dropColumn('modules');
        });
    }
};
