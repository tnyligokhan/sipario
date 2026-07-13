<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * orders — sipariş başlığı. status ve total_kurus ÖNBELLEKtir (DECISIONS: kaynak order_events);
 * sorgu kolaylığı için tutulur, doğruluğun kaynağı olay tablosudur. Sunucu push'ta olaylardan türetir.
 *
 * customer_id nullable: müşterisiz (anlık) sipariş de olabilir. payment_type nullable (teslimde belirlenir).
 * Para bigint kuruş. Composite FK (tenant_id, customer_id) → customers; MATCH SIMPLE ile null customer_id serbest.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('customer_id')->nullable();
            $table->string('status', 20)->default('open');    // önbellek: open|delivered|cancelled
            $table->bigInteger('total_kurus')->default(0);     // önbellek: aktif satır toplamı
            $table->string('payment_type', 20)->nullable();    // nakit|kart|havale|veresiye
            $table->text('note')->nullable();
            $table->timestampTz('occurred_at')->useCurrent();
            $table->uuid('created_device_id')->nullable();
            $table->timestampTz('deleted_at')->nullable();
            $table->timestampsTz();

            // Doğrudan tenant FK: müşterisiz (customer_id NULL) siparişin de tenant silinince
            // cascade ile temizlenmesini garanti eder (composite FK MATCH SIMPLE null'da atlanır).
            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'customer_id'])
                ->references(['tenant_id', 'id'])->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'customer_id']);
        });

        DB::statement(
            'ALTER TABLE orders ADD CONSTRAINT orders_status_check '.
            "CHECK (status IN ('open','delivered','cancelled'))"
        );
        DB::statement(
            'ALTER TABLE orders ADD CONSTRAINT orders_payment_type_check '.
            "CHECK (payment_type IS NULL OR payment_type IN ('nakit','kart','havale','veresiye'))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
