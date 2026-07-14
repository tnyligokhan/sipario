<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * ledger_entries — defterin APPEND-ONLY kalbi (kırmızı çizgi #2). Para/hareket kayıtları
 * silinmez/ezilmez; düzeltme yalnız ters kayıtla (entry_type='correction', amount_kurus signed).
 * customers.balance_kurus bu tablodan türetilen önbellektir.
 *
 * FAZ 2 KAPSAMI: şema + RLS + senkron hattı kurulur; defteri ÜRETEN iş akışları (veresiye, kasa,
 * kupon, gün sonu) FAZ 3'tür. Bu fazda outbox/pull hattının baştan doğru olması için tablo hazır.
 *
 * unique(['tenant_id','client_event_id']): idempotency. occurred_at düzeltilmiş sunucu saatiyle.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ledger_entries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('customer_id')->nullable();
            $table->string('entry_type', 30);
            $table->bigInteger('amount_kurus'); // signed: düzeltme ters kayıt
            $table->uuid('related_order_id')->nullable();
            $table->text('note')->nullable();
            $table->timestampTz('occurred_at');
            $table->uuid('device_id')->nullable();
            $table->uuid('client_event_id');
            $table->timestampTz('created_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'customer_id'])
                ->references(['tenant_id', 'id'])->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'client_event_id']);
            $table->index(['tenant_id', 'customer_id']);
        });

        DB::statement(
            'ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_type_check '.
            "CHECK (entry_type IN ('debit','credit','payment','coupon_grant','coupon_use','correction'))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('ledger_entries');
    }
};
