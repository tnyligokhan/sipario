<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * FAZ 3 — orders.payment_type CHECK'ine 'kupon' eklenir (DECISIONS "Faz 3 — mimari").
 *
 * Kuponla ödenen teslimatın ödeme tipi nakit/kart/havale/veresiye'nin hiçbiri değildir: mal peşin
 * ödenmiş kupon paketinden düşer, 0 para hareketi + 1 kupon kullanımı üretir. 'veresiye' zaten
 * Faz 2'de vardı; yalnız 'kupon' ekleniyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE orders DROP CONSTRAINT orders_payment_type_check');
        DB::statement(
            'ALTER TABLE orders ADD CONSTRAINT orders_payment_type_check '.
            "CHECK (payment_type IS NULL OR payment_type IN ('nakit','kart','havale','veresiye','kupon'))"
        );
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE orders DROP CONSTRAINT orders_payment_type_check');
        DB::statement(
            'ALTER TABLE orders ADD CONSTRAINT orders_payment_type_check '.
            "CHECK (payment_type IS NULL OR payment_type IN ('nakit','kart','havale','veresiye'))"
        );
    }
};
