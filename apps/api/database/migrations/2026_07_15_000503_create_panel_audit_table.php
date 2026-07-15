<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 5c — panel denetim günlüğü. Her panel eylemi (deneme uzat, abonelik kaydet, kilitle/aç,
 * suspend, elle tenant aç) KİM tarafından, HANGİ bayide, NE zaman yapıldığı append kaydı bırakır —
 * destek aracının hesap verebilirliği. KVKK: yalnız eylem türü + hedef id'ler; müşteri/iş verisi
 * DEĞERİ yazılmaz (kırmızı çizgi #4).
 *
 * RLS YOK (panel altyapısı, sipario_panel BYPASSRLS zaten cross-tenant görür). sipario_panel
 * SELECT/INSERT grant'ine sahip (migration 000504); UPDATE/DELETE yok — günlük ezilmez.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('panel_audit', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('admin_user_id')->nullable();   // eylemi yapan admin
            $table->uuid('tenant_id')->nullable();       // hedef bayi (varsa)
            $table->string('action', 50);                // extend_trial | activate | lock | unlock | suspend | create_tenant ...
            $table->text('detail')->nullable();          // nötr özet (PII YOK)
            $table->timestampTz('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('panel_audit');
    }
};
