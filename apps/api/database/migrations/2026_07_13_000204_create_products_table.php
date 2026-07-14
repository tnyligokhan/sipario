<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * products — bayinin ürün kataloğu (damacana, adet, litre...). unit_price_kurus bugünkü fiyat;
 * siparişe düşen fiyat order_lines'ta AYRICA saklanır (DECISIONS: satırdaki fiyat siparişin
 * çekildiği andaki gerçektir, ürünün bugünkü fiyatının fonksiyonu değil).
 *
 * unit serbest string (CHECK yok) — birim bayiden bayiye değişir, gevşek tutulur (architect kararı).
 * is_active: pasifleme (silme yerine); geçmiş siparişler product_name/price'ı satırda taşıdığından bozulmaz.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->string('name', 160);
            $table->bigInteger('unit_price_kurus');
            $table->string('unit', 20)->default('adet');
            $table->boolean('is_active')->default(true);
            $table->timestampTz('updated_occurred_at')->useCurrent(); // LWW meta
            $table->uuid('updated_device_id')->nullable();
            $table->timestampTz('deleted_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index('tenant_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
