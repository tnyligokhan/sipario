<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Append-only değişmezliğini VERİTABANI SEVİYESİNDE zorlar (kırmızı çizgi #2 savunma-derinliği).
 *
 * 210 migration'ı sipario_app'e tüm Faz 2 tablolarında UPDATE/DELETE verdi. Ama ledger_entries,
 * order_events, sync_changes ve processed_events APPEND-ONLY'dir — uygulama bunlara yalnız INSERT
 * eder, asla update/delete yapmaz. Yetkiyi geri alarak bir kod hatasının veya ileride dikkatsiz bir
 * yazımın defter/olay geçmişini SESSİZCE ezmesini/silmesini imkânsız kılıyoruz (reviewer bulgusu).
 *
 * FORCE RLS "yanlışlıkla owner ile bağlanılsa bile" felsefesiyle simetrik: kritik değişmez koda değil
 * veritabanı iznine bağlanır. Meşru düzeltme yine mümkün — ters kayıtla (append), ezmeyle değil.
 * sipario_owner (superuser) bu revoke'tan etkilenmez; migration/bakım yolu açık kalır.
 *
 * tenant_sync_state DAHİL DEĞİL: seq sayacı push'ta UPDATE edilir (append-only değil).
 */
return new class extends Migration
{
    private const APPEND_ONLY = ['ledger_entries', 'order_events', 'sync_changes', 'processed_events'];

    public function up(): void
    {
        $tables = implode(', ', self::APPEND_ONLY);
        DB::unprepared("REVOKE UPDATE, DELETE ON {$tables} FROM sipario_app;");
    }

    public function down(): void
    {
        $tables = implode(', ', self::APPEND_ONLY);
        DB::unprepared("GRANT UPDATE, DELETE ON {$tables} TO sipario_app;");
    }
};
