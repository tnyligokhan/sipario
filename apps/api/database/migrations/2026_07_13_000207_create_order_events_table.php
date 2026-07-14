<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * order_events — siparişin OLAY defteri (DECISIONS: orders.status/total önbellek, kaynak burası).
 * APPEND-ONLY: bu tabloya UPDATE/DELETE yolu yoktur (yalnız down() drop eder). occurred_at
 * düzeltilmiş sunucu saatiyle yazılır (istemci offset'i). created_at yalnız kayıt anıdır.
 *
 * unique(['tenant_id','client_event_id']): idempotency — aynı olay iki kez push edilirse ikinci
 * INSERT çakışır, SyncService duplicate olarak ele alır (retry her zaman güvenli — DECISIONS senkron).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('order_id');
            $table->string('event_type', 30);
            $table->jsonb('payload')->nullable();
            $table->uuid('client_event_id');
            $table->timestampTz('occurred_at');
            $table->uuid('device_id')->nullable();
            $table->timestampTz('created_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'order_id'])
                ->references(['tenant_id', 'id'])->on('orders')->cascadeOnDelete();
            $table->unique(['tenant_id', 'client_event_id']);
            $table->index(['tenant_id', 'order_id']);
        });

        DB::statement(
            'ALTER TABLE order_events ADD CONSTRAINT order_events_type_check '.
            "CHECK (event_type IN ('created','line_added','line_removed','delivered','cancelled','payment_set','note_set'))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('order_events');
    }
};
