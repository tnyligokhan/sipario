<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * EK PAKET TANIMLAMALARI — "hangi bayiye, ne zaman, hangi paketi verdik" (tasarım `TanimlaModal`).
 *
 * APPEND-ONLY (kırmızı çizgi #2 felsefesi). Bir tanımlama, bayinin kotasını GERÇEKTEN büyütmüştür:
 * kontör harcanmış, kurye hesabı açılmıştır. Satırı sonradan düzeltmek/silmek, kotayı geri
 * alamayacağı için yalnız KAYDI yalanlar. Yanlış tanımlama, yeni bir tanımlama (ya da elle kota
 * düzeltmesi) ile kapatılır — ledger_entries 211 / cash_handovers 405 deseninin aynısı.
 *
 * PAKET ADI KOPYALANIR (`package_name`, `type`, `quantity`): paket satırı bir gün silinirse
 * (bugün silmiyoruz ama garanti kod disiplinine bırakılamaz) geçmiş tanımlama "Silinmiş paket"
 * demesin. `addon_package_id` NULLABLE + nullOnDelete: bağ kopar, kayıt okunur kalır.
 *
 * `collection_method = 'bedelsiz'` → `amount_kurus = 0` ve GELİR KAYDI OLUŞMAZ (tasarımın modal
 * notu: "Bedelsiz tanımlandığı için gelir kaydı oluşmaz"). Ücretli tanımlama ayrıca
 * `subscription_payments`'a `period='addon'` satırı yazar; gelir raporu tek yerden okunur.
 *
 * NEDEN `granted_on` DATE, `created_at` TIMESTAMP: tanımlama TARİHİ operatörün seçtiği iş günüdür
 * (dünkü havale bugün girilebilir); `created_at` kaydın sisteme düştüğü andır. İkisi farklı sorulara
 * cevap verir ve karıştırılırsa aylık gelir raporu kayar.
 *
 * RLS + izin matrisi: 005010 (panel SELECT) ve 005011 (tenant_isolation). sipario_app bu tabloyu
 * GÖRMEZ — bayiye "sana şu paketi bedelsiz verdik" bilgisi gösterilmez.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('addon_grants', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('addon_package_id')->nullable();
            $table->string('package_name', 120);
            $table->string('type', 10);                 // credits | courier
            $table->integer('quantity');
            $table->bigInteger('amount_kurus')->default(0);
            $table->string('collection_method', 10);    // iban | elden | bedelsiz
            $table->date('granted_on');
            $table->text('note')->nullable();
            $table->uuid('admin_user_id')->nullable();
            $table->timestampTz('created_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign('addon_package_id')->references('id')->on('addon_packages')->nullOnDelete();
            $table->index(['tenant_id', 'granted_on']);
            $table->index('granted_on');
        });

        DB::statement(
            'ALTER TABLE addon_grants ADD CONSTRAINT addon_grants_type_check '.
            "CHECK (type IN ('credits','courier'))"
        );
        DB::statement(
            'ALTER TABLE addon_grants ADD CONSTRAINT addon_grants_method_check '.
            "CHECK (collection_method IN ('iban','elden','bedelsiz'))"
        );
        // Bedelsiz tanımlama ÜCRETSİZDİR: tutarın sıfır olması kod kuralı değil DB kuralıdır,
        // yoksa "bedelsiz" etiketli bir satır gelir raporuna sızabilir.
        DB::statement(
            'ALTER TABLE addon_grants ADD CONSTRAINT addon_grants_amount_check '.
            "CHECK (quantity > 0 AND amount_kurus >= 0 AND (collection_method <> 'bedelsiz' OR amount_kurus = 0))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('addon_grants');
    }
};
