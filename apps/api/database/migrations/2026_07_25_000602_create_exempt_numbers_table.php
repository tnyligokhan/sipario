<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * exempt_numbers — muaf telefonlar (tasarım: "Muaf Telefonlar"). Bu numaralar aradığında arayan
 * tanıma kartı GÖSTERİLMEZ (kurye, tedarikçi, kişisel numaralar).
 *
 * phone_last10 customer_phones ile AYNI eşleşme anahtarıdır (son 10 hane, DECISIONS): native taraf
 * sipario.db'yi salt-okunur açıp kart çizmeden ÖNCE bu tabloyu de sorgular — indeks 1 sn bütçesinin
 * parçasıdır. Bu yüzden Drift aynasında da bulunmak ZORUNDA (yalnız sunucuda yaşayamaz).
 *
 * Tekillik DB'de ZORLANMAZ (bilinçli): iki cihaz çevrimdışıyken aynı numarayı muaf yaparsa unique
 * ihlali olayı REDDEDER ve kullanıcının işlemi kaybolurdu. Mükerrer muaf kayıt zararsızdır (aynı
 * sonucu verir), UI zaten uyarır. Aynı çizgi: products.barcode (migration 605).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('exempt_numbers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->string('phone_e164', 32);
            $table->string('phone_last10', 10);
            $table->string('label', 60)->nullable();
            $table->timestampTz('updated_occurred_at')->useCurrent(); // LWW meta
            $table->uuid('updated_device_id')->nullable();
            $table->timestampTz('deleted_at')->nullable();            // tombstone
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'phone_last10']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('exempt_numbers');
    }
};
