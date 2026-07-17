<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * cash_handovers APPEND-ONLY değişmezliğini VERİTABANI SEVİYESİNDE zorlar (kırmızı çizgi #2,
 * ledger_entries 211 / coupon_movements 305 deseni). Uygulama bu tabloya yalnız INSERT eder;
 * UPDATE/DELETE yetkisi geri alınır ki bir kod hatası bile devir geçmişini/fark kanıtını sessizce
 * ezemesin/silemesin. Düzeltme yalnız yeni devir kaydı veya ledger correction ile (append).
 *
 * sipario_owner (superuser) revoke'tan etkilenmez (bakım açık).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared('REVOKE UPDATE, DELETE ON cash_handovers FROM sipario_app;');
    }

    public function down(): void
    {
        DB::unprepared('GRANT UPDATE, DELETE ON cash_handovers TO sipario_app;');
    }
};
