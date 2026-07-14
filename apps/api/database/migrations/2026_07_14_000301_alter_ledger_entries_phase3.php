<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 3 — ledger_entries defter iş akışlarına hazırlanır (DECISIONS "Faz 3 — mimari").
 *
 *  - payment_type (nakit|kart|havale, nullable): kasa özeti "ödeme tipine göre" join'siz gruplasın
 *    diye ZORUNLU kolon; yalnız entry_type='payment' iken dolu olabilir (app doğrulaması).
 *  - reverses_entry_id (nullable, self-FK): ters kaydı (correction) düzelttiği satıra bağlar —
 *    "eksik para kanıt olarak görünür kalmalı" (BRIEF). Bileşik (tenant_id, reverses_entry_id)
 *    self-FK cross-tenant referansı imkânsız kılar.
 *  - entry_type CHECK para-set'ine daraltılır ('debit','credit','payment','correction');
 *    coupon_grant/coupon_use kupon tablosuna taşındı (Faz 2 hiç ledger iş satırı yazmadı, kayıp yok).
 *
 * Bileşik self-FK için ledger_entries'e unique(tenant_id, id) EKLENİR (Faz 2'de yalnız PK(id) +
 * unique(tenant_id, client_event_id) vardı; bileşik referans hedef sütunlarında unique ister).
 *
 * Migration owner (sipario_owner) ile koşar; append-only REVOKE yalnız sipario_app'i etkiler.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ledger_entries', function (Blueprint $table) {
            $table->string('payment_type', 20)->nullable()->after('amount_kurus');
            $table->uuid('reverses_entry_id')->nullable()->after('related_order_id');
            $table->unique(['tenant_id', 'id']);
        });

        DB::statement(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_payment_type_check '.
            "CHECK (payment_type IS NULL OR payment_type IN ('nakit','kart','havale'))"
        );

        // Bileşik self-FK: ters kayıt yalnız AYNI bayinin bir defter satırını düzeltebilir.
        DB::statement(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_reverses_fk '.
            'FOREIGN KEY (tenant_id, reverses_entry_id) '.
            'REFERENCES ledger_entries (tenant_id, id)'
        );

        // entry_type CHECK'ini para-set'ine daralt (kupon değerleri düşer).
        DB::statement('ALTER TABLE ledger_entries DROP CONSTRAINT ledger_entries_type_check');
        DB::statement(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_type_check '.
            "CHECK (entry_type IN ('debit','credit','payment','correction'))"
        );
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE ledger_entries DROP CONSTRAINT ledger_entries_type_check');
        DB::statement(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_type_check '.
            "CHECK (entry_type IN ('debit','credit','payment','coupon_grant','coupon_use','correction'))"
        );
        DB::statement('ALTER TABLE ledger_entries DROP CONSTRAINT ledger_entries_reverses_fk');
        DB::statement('ALTER TABLE ledger_entries DROP CONSTRAINT ledger_entries_payment_type_check');

        Schema::table('ledger_entries', function (Blueprint $table) {
            $table->dropUnique(['tenant_id', 'id']);
            $table->dropColumn(['payment_type', 'reverses_entry_id']);
        });
    }
};
