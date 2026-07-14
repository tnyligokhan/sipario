<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 3 — kupon (DECISIONS "Faz 3 — mimari"). Kupon PARA değil ADET: müşteri N damacanalık paketi
 * peşin alır, her teslimde bir adet düşülür. Paranın parası zaten normal debit+payment ile deftere
 * düşer; burada yalnız ADET izlenir ("para her yerde kuruş int" felsefesi bozulmaz).
 *
 *  - coupon_movements: APPEND-ONLY (ledger_entries kalıbı, kırmızı çizgi #2). qty_delta İMZALI
 *    (grant +N, use −qty, correction imzalı). Düzeltme yalnız ters hareketle (reverses_movement_id).
 *  - coupon_balances: ÖNBELLEK (customers.balance_kurus ikizi). balance_qty = SUM(qty_delta);
 *    UPDATE'lenir (append DEĞİL), bozulursa hareketlerden yeniden kurulur. Eksiye düşebilir (KABUL).
 *
 * product_id NULL = genel kupon (ürün ayrımsız). Postgres'te NULL'lar unique'te ayrı sayılır;
 * (tenant_id, customer_id, product_id) tekilliği UNIQUE NULLS NOT DISTINCT ile kurulur (PG 15+).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('coupon_movements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('customer_id');                 // NOT NULL: kupon müşteriye ait
            $table->uuid('product_id')->nullable();      // null = genel kupon
            $table->string('movement_type', 20);         // grant|use|correction
            $table->integer('qty_delta');                // imzalı: grant +N, use −qty
            $table->uuid('related_order_id')->nullable();
            $table->text('note')->nullable();
            $table->uuid('reverses_movement_id')->nullable();
            $table->timestampTz('occurred_at');
            $table->uuid('device_id')->nullable();
            $table->uuid('client_event_id');
            $table->timestampTz('created_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'customer_id'])
                ->references(['tenant_id', 'id'])->on('customers')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'product_id'])
                ->references(['tenant_id', 'id'])->on('products');
            $table->foreign(['tenant_id', 'related_order_id'])
                ->references(['tenant_id', 'id'])->on('orders');
            $table->unique(['tenant_id', 'client_event_id']);
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'customer_id']);
        });

        // Bileşik self-FK closure DIŞINDA eklenir: hedef unique(tenant_id, id) tablo kurulduktan
        // SONRA var olur; aynı closure'da eklersek FK unique'ten önce koşup patlar (self-ref).
        DB::statement(
            'ALTER TABLE coupon_movements ADD CONSTRAINT coupon_movements_reverses_fk '.
            'FOREIGN KEY (tenant_id, reverses_movement_id) '.
            'REFERENCES coupon_movements (tenant_id, id)'
        );

        DB::statement(
            'ALTER TABLE coupon_movements ADD CONSTRAINT coupon_movements_type_check '.
            "CHECK (movement_type IN ('grant','use','correction'))"
        );

        Schema::create('coupon_balances', function (Blueprint $table) {
            // Surrogate uuid id: sync_changes.entity_id NOT NULL uuid ister; upsert bileşik
            // (tenant_id,customer_id,product_id) ile yapılır, id çakışmada korunur (kararlı).
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('customer_id');
            $table->uuid('product_id')->nullable();
            $table->integer('balance_qty')->default(0);

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'customer_id'])
                ->references(['tenant_id', 'id'])->on('customers')->cascadeOnDelete();
            $table->index(['tenant_id', 'customer_id']);
        });

        // (tenant_id, customer_id, product_id) tekil — NULL product_id (genel kupon) tek satır kalsın
        // diye NULLS NOT DISTINCT (PG 15+); normal unique NULL'ları ayrı sayıp çoğaltırdı.
        DB::statement(
            'ALTER TABLE coupon_balances ADD CONSTRAINT coupon_balances_unique '.
            'UNIQUE NULLS NOT DISTINCT (tenant_id, customer_id, product_id)'
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('coupon_balances');
        Schema::dropIfExists('coupon_movements');
    }
};
