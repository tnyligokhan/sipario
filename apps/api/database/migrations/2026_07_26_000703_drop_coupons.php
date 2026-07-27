<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * KUPON KALDIRILDI (2026-07-26 tasarım kararı). Tasarım kuponu üründen çıkardı: hiçbir ekran onu
 * çizmiyor, ödeme tipleri yalnız nakit/kart/havale/veresiye. Arayüz, Drift şeması (v10), sync
 * applier ve modeller silindi; burada sunucu şeması kapatılıyor.
 *
 * Üç iş:
 *  1. coupon_movements + coupon_balances DÜŞÜRÜLÜR. DROP TABLE tablonun policy'lerini, indekslerini
 *     ve grant'larını (sipario_app yazma, sipario_panel SELECT) KENDİSİYLE BİRLİKTE götürür — 303/304/
 *     305/504 migration'larında verilenler ayrıca geri alınmaz, alınamaz da (nesne yok).
 *  2. orders.payment_type CHECK'i 302'nin TERSİ olarak daraltılır: 'kupon' çıkar.
 *  3. Kalan 'kupon' ödeme tipli sipariş satırları NULL'a çekilir — yoksa daraltılan CHECK onları
 *     reddeder ve migration düşerdi.
 *
 * (3) NEDEN VERİ KAYBI DEĞİL: kuponla teslim HİÇ para hareketi üretmiyordu (mal peşin ödenmiş
 * paketten düşerdi), dolayısıyla defterde mutabakat gerektiren bir satır yok — kırmızı çizgi #2'ye
 * dokunulmuyor, tek bir ledger_entries satırı bile silinmiyor/ezilmiyor. Siparişin "kuponla teslim
 * edildiği" olgusu APPEND-ONLY order_events'te payload içinde AYNEN durur; orders.payment_type ise
 * o olay günlüğünden türeyen bir ÖNBELLEKTİR. Tarihsel kayıt kaybolmuyor, yalnız önbellek artık
 * kabul edilmeyen bir değeri taşımıyor.
 */
return new class extends Migration
{
    private const TABLES = ['coupon_movements', 'coupon_balances'];

    public function up(): void
    {
        // Önbelleği temizle (CHECK daraltmasından ÖNCE olmak zorunda).
        DB::statement("UPDATE orders SET payment_type = NULL WHERE payment_type = 'kupon'");

        DB::statement('ALTER TABLE orders DROP CONSTRAINT orders_payment_type_check');
        DB::statement(
            'ALTER TABLE orders ADD CONSTRAINT orders_payment_type_check '.
            "CHECK (payment_type IS NULL OR payment_type IN ('nakit','kart','havale','veresiye'))"
        );

        // Sıra önemli: balances'ın FK'si yok ama movements'ın self-FK'si var; ikisini de düşürmek
        // için bağımlılık yönü fark etmez, yine de kurulum sırasının tersine gidilir.
        Schema::dropIfExists('coupon_balances');
        Schema::dropIfExists('coupon_movements');
    }

    /**
     * ŞEMA geri kurulur (303 + 304 + 305 + 504'ün kupon kısımlarının birleşimi), CHECK 302'deki
     * geniş hâline döner.
     *
     * DÜRÜST UYARI — VERİ GERİ GELMEZ: up() tabloları DÜŞÜRDÜĞÜ için kupon hareketleri ve bakiyeleri
     * kalıcı olarak gitmiştir; down() BOŞ tablolar kurar. Aynı şekilde up()'ta NULL'a çekilen
     * orders.payment_type değerleri de 'kupon'a geri yazılmaz (hangi satırların NULL'ı kupondan
     * geldiği tutulmuyor) — o olgu order_events'te durur, oradan elle türetilebilir.
     */
    public function down(): void
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

        // Bileşik self-FK closure DIŞINDA (303'teki gerekçe): hedef unique(tenant_id, id) tablo
        // kurulduktan SONRA var olur.
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

        DB::statement(
            'ALTER TABLE coupon_balances ADD CONSTRAINT coupon_balances_unique '.
            'UNIQUE NULLS NOT DISTINCT (tenant_id, customer_id, product_id)'
        );

        // RLS + policy (304) — güvenli varsayılan: app.tenant_id yoksa hiçbir satır görünmez.
        foreach (self::TABLES as $table) {
            DB::unprepared(<<<SQL
                ALTER TABLE {$table} ENABLE ROW LEVEL SECURITY;
                ALTER TABLE {$table} FORCE ROW LEVEL SECURITY;
                CREATE POLICY tenant_isolation ON {$table}
                    USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                    WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
            SQL);
        }

        DB::unprepared(<<<'SQL'
            GRANT SELECT, INSERT, UPDATE, DELETE ON coupon_movements, coupon_balances TO sipario_app;
            -- 305: hareket tablosu APPEND-ONLY (düzeltme yalnız ters hareketle). Bakiye ÖNBELLEK,
            -- UPDATE'i açık kalır.
            REVOKE UPDATE, DELETE ON coupon_movements FROM sipario_app;
            -- 504: panel yalnız OKUR.
            GRANT SELECT ON coupon_movements, coupon_balances TO sipario_panel;
        SQL);

        DB::statement('ALTER TABLE orders DROP CONSTRAINT orders_payment_type_check');
        DB::statement(
            'ALTER TABLE orders ADD CONSTRAINT orders_payment_type_check '.
            "CHECK (payment_type IS NULL OR payment_type IN ('nakit','kart','havale','veresiye','kupon'))"
        );
    }
};
