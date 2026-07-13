<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * order_lines — sipariş satırları. product_name ve unit_price_kurus SATIRDA saklanır
 * (DECISIONS: siparişin çekildiği andaki gerçek; ürünün bugünkü fiyatının fonksiyonu değil).
 *
 * product_id yumuşak referanstır (FK YOK): satır ürün silinse/pasiflense de bozulmamalı —
 * bütün gerçeği zaten kendi taşır. Bütünlük order_id composite FK + doğrudan tenant FK ile.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_lines', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('order_id');
            $table->uuid('product_id')->nullable(); // yumuşak referans (snapshot satırda)
            $table->string('product_name', 160);
            $table->bigInteger('unit_price_kurus');
            $table->integer('qty');
            $table->bigInteger('line_total_kurus');
            $table->timestampTz('deleted_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'order_id'])
                ->references(['tenant_id', 'id'])->on('orders')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'order_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_lines');
    }
};
