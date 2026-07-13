<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * customer_phones — bir müşterinin birden çok numarası (ev, cep) — DECISIONS: 1NF, arayan tanıma
 * ikinci numarada kör kalmasın. phone_last10 arayan tanımanın eşleşme anahtarıdır (son 10 hane
 * ülke içinde tekildir); (tenant_id, phone_last10) indeksi 1 sn bütçesinin dayanağıdır.
 *
 * Composite FK (tenant_id, customer_id) → customers(tenant_id, id): kiracı-içi tutarlılık DB'de zorlanır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_phones', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('customer_id');
            $table->string('phone_e164', 32);
            $table->string('phone_last10', 10);
            $table->string('label', 20)->nullable();
            $table->boolean('is_primary')->default(false);
            $table->timestampTz('updated_occurred_at')->useCurrent(); // LWW meta
            $table->uuid('updated_device_id')->nullable();
            $table->timestampTz('deleted_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'customer_id'])
                ->references(['tenant_id', 'id'])->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'phone_last10']);
            $table->index(['tenant_id', 'customer_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_phones');
    }
};
