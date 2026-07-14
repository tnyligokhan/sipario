<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Senkron altyapısı (DECISIONS senkron): tek yazma yüzeyi push, tek okuma yüzeyi delta pull.
 *
 *  - tenant_sync_state: tenant başına MONOTON sequence sayacı. Push'ta FOR UPDATE ile kilitlenir;
 *    seq atama sırası = commit sırası → kayıp-güncelleme sınıfı kapanır (korku #2, defter tutarlılığı).
 *  - sync_changes: değişiklik günlüğü (CDC). Delta pull KAYNAĞI: seq > since sıralı okunur. APPEND-ONLY.
 *  - processed_events: (tenant_id, client_event_id) idempotency defteri; retry çift-uygulama yapmaz.
 *
 * Bu üç tablo iş verisi değil altyapıdır; yine de RLS'e tabidir (2026_07_13_000210).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_sync_state', function (Blueprint $table) {
            $table->uuid('tenant_id')->primary();
            $table->bigInteger('last_seq')->default(0);
            $table->timestampTz('updated_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
        });

        // Mevcut tenant'lar için başlangıç satırı (yeni tenant satırını Provisioning/CreateTenant ekler).
        DB::statement('INSERT INTO tenant_sync_state (tenant_id, last_seq) SELECT id, 0 FROM tenants');

        Schema::create('sync_changes', function (Blueprint $table) {
            $table->bigIncrements('id');            // fiziksel PK (bigserial)
            $table->uuid('tenant_id');
            $table->bigInteger('seq');              // tenant içi monoton sıra
            $table->string('entity_type', 40);
            $table->uuid('entity_id');
            $table->string('op', 10);               // upsert|delete
            $table->jsonb('payload')->nullable();
            $table->timestampTz('occurred_at')->nullable();
            $table->uuid('device_id')->nullable();
            $table->timestampTz('created_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'seq']);
            $table->index(['tenant_id', 'seq']);
        });

        DB::statement(
            'ALTER TABLE sync_changes ADD CONSTRAINT sync_changes_op_check '.
            "CHECK (op IN ('upsert','delete'))"
        );

        Schema::create('processed_events', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->uuid('tenant_id');
            $table->uuid('client_event_id');
            $table->string('entity_type', 40);
            $table->uuid('entity_id')->nullable();
            $table->bigInteger('result_seq')->nullable();
            $table->timestampTz('created_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'client_event_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('processed_events');
        Schema::dropIfExists('sync_changes');
        Schema::dropIfExists('tenant_sync_state');
    }
};
