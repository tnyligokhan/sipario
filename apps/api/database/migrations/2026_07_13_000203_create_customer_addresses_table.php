<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * customer_addresses — bir müşterinin birden çok adresi (ev, işyeri) — DECISIONS: 1NF.
 * lat/lng opsiyonel (konum alınamıyorsa teslim ASLA bloklanmaz — BRIEF). LWW meta + tombstone.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_addresses', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('customer_id');
            $table->string('label', 20)->nullable();
            $table->text('address_text');
            $table->double('lat')->nullable();
            $table->double('lng')->nullable();
            $table->boolean('is_primary')->default(false);
            $table->timestampTz('updated_occurred_at')->useCurrent(); // LWW meta
            $table->uuid('updated_device_id')->nullable();
            $table->timestampTz('deleted_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'customer_id'])
                ->references(['tenant_id', 'id'])->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'customer_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_addresses');
    }
};
