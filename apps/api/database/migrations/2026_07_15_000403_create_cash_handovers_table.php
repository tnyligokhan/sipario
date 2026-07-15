<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 4 — KASA DEVRİ kalıcı append-only mutabakat kaydı (DECISIONS "Faz 4 — mimari"). Kurye gün sonu
 * kasayı patrona devreder; kayıt SAYILAN nakdi (counted_cash_kurus) + sistemin o an beklediğini
 * (expected_cash_kurus, anlık snapshot) + farkı (diff_kurus, denetim için) taşır.
 *
 * Append-only (ledger_entries 211 / coupon 305 deseni; REVOKE ayrı migration'da): fark KANIT olarak
 * görünür kalır (BRIEF "eksik para kanıt olarak görünür kalmalı"), düzeltme yeni devir veya ledger
 * correction ile — asla ezme.
 *
 * from_user_id (kurye) / to_user_id (patron, nullable): SERT FK YOK — kullanıcı silinse de devir
 * kaydı kanıt kalır; izolasyon yazımdan önce RLS-kapsamlı User::exists() ile korunur. Doğrudan
 * tenant_id→tenants cascade FK + unique(tenant_id,id) (Faz 1/2/3 deseni).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cash_handovers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('from_user_id');                       // kurye (kasayı devreden)
            $table->uuid('to_user_id')->nullable();             // patron (kasayı alan)
            $table->bigInteger('counted_cash_kurus');           // sayılan nakit
            $table->bigInteger('expected_cash_kurus');          // sistemin beklediği (anlık snapshot)
            $table->bigInteger('diff_kurus');                   // counted − expected (kanıt)
            $table->timestampTz('period_start')->nullable();    // önceki devir / gün başı occurred_at
            $table->timestampTz('occurred_at');
            $table->uuid('device_id')->nullable();
            $table->text('note')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'from_user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cash_handovers');
    }
};
