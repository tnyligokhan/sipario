<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 5b — abonelik ödemeleri APPEND-ONLY denetim kaydı (DECISIONS "Faz 5 — mimari"). Her ödeme
 * girişimi (initiated) ve sonucu (success/failed) AYRI satırdır (ledger deseni — durum UPDATE'lenmez,
 * yeni satır eklenir). Para İMZASIZ int KURUŞ. Callback İDEMPOTENT: aynı provider_ref success iki kez
 * gelirse tek aktivasyon (SubscriptionService kontrol eder + partial unique index emniyet).
 *
 * KVKK: kart verisi ASLA yazılmaz (iyzico saklar); yalnız tutar + sağlayıcı referansı + onay sürümü +
 * zaman. Aktivasyon (valid_until uzatma) SUNUCUda (owner) yapılır — abonelik durumu tek doğru kaynak.
 *
 * RLS + REVOKE UPDATE/DELETE bir sonraki migration'da (ledger_entries 211 / cash_handovers 405 deseni).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('subscription_payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->bigInteger('amount_kurus');
            $table->string('currency', 3)->default('TRY');
            $table->string('provider', 20)->default('iyzico');
            $table->string('provider_ref');                  // idempotensi anahtarı (conversationId)
            $table->string('status', 20);                    // initiated | success | failed
            $table->string('consent_version')->nullable();   // kabul edilen hukuk metni sürüm(ler)i
            $table->timestampTz('consented_at')->nullable();
            $table->timestampTz('occurred_at');
            $table->timestampTz('created_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'provider_ref']);
        });

        DB::statement(
            'ALTER TABLE subscription_payments ADD CONSTRAINT subscription_payments_status_check '.
            "CHECK (status IN ('initiated','success','failed'))"
        );

        // İdempotensi emniyeti: bir provider_ref için EN FAZLA bir 'success' satırı (yarış-korumalı).
        DB::statement(
            'CREATE UNIQUE INDEX subscription_payments_success_ref '.
            "ON subscription_payments (provider_ref) WHERE status = 'success'"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('subscription_payments');
    }
};
