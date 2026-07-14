<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * coupon_movements APPEND-ONLY değişmezliğini VERİTABANI SEVİYESİNDE zorlar (kırmızı çizgi #2,
 * 000211 deseni). Uygulama bu tabloya yalnız INSERT eder; UPDATE/DELETE yetkisi geri alınır ki bir
 * kod hatası bile kupon geçmişini sessizce ezemesin/silemesin. Düzeltme yalnız ters hareketle
 * (movement_type='correction', append).
 *
 * coupon_balances DAHİL DEĞİL: önbellek (customers.balance_kurus gibi), harekelerden yeniden
 * kurulmak üzere UPDATE'lenir. sipario_owner (superuser) revoke'tan etkilenmez (bakım açık).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared('REVOKE UPDATE, DELETE ON coupon_movements FROM sipario_app;');
    }

    public function down(): void
    {
        DB::unprepared('GRANT UPDATE, DELETE ON coupon_movements TO sipario_app;');
    }
};
