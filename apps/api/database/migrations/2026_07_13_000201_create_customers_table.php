<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * customers — bayinin müşterileri. Kimlik İSTEMCİDE üretilir (UUIDv7, offline-first).
 *
 *  - balance_kurus: OKUMA-MODELİ ÖNBELLEĞİ (DECISIONS). Doğruluğun kaynağı ledger_entries;
 *    bu sütun arayan tanımanın 1 sn bütçesinde tek-satır okuma içindir, defterden türetilir.
 *  - updated_occurred_at / updated_device_id: LWW (son yazan kazanır) meta — varlık alanlarında
 *    çakışma çözümü (DECISIONS: adres para değildir, eşitlikte device_id ile deterministik ayrım).
 *  - deleted_at: tombstone. Silme FİZİKSEL değildir; senkron sırasında satır durur, sadece işaretlenir.
 *
 * unique(['tenant_id','id']): (tenant_id, parent_id) bileşik yabancı anahtarların referans noktası
 * (DECISIONS: tutarlılık DB seviyesinde zorlanır). RLS 2026_07_13_000210'da etkinleşir.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->string('name', 160);
            $table->text('note')->nullable();
            $table->bigInteger('balance_kurus')->default(0); // önbellek; kaynak ledger_entries
            $table->timestampTz('updated_occurred_at')->useCurrent(); // LWW meta
            $table->uuid('updated_device_id')->nullable();
            $table->timestampTz('deleted_at')->nullable(); // tombstone
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index('tenant_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customers');
    }
};
