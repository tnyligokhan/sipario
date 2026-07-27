<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * day_closings APPEND-ONLY değişmezliğini VERİTABANI SEVİYESİNDE zorlar (kırmızı çizgi #2;
 * ledger_entries 211 / coupon_movements 305 / cash_handovers 405 deseni).
 *
 * Kapanış bir mutabakat KANITIDIR: sayılan/beklenen/fark ile "gün kapatıldı" ifadesi ancak
 * ezilemezse anlam taşır. Uygulama bu tabloya yalnız INSERT eder; yanlış kapanış YENİ kapanış
 * kaydıyla düzeltilir. sipario_owner (superuser) revoke'tan etkilenmez (bakım açık).
 *
 * tenant_settings / exempt_numbers / call_logs BU KAPSAMDA DEĞİL — onlar düzenlenebilir varlıklardır
 * (LWW + tombstone), para/hareket kaydı değil.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared('REVOKE UPDATE, DELETE ON day_closings FROM sipario_app;');
    }

    public function down(): void
    {
        DB::unprepared('GRANT UPDATE, DELETE ON day_closings TO sipario_app;');
    }
};
