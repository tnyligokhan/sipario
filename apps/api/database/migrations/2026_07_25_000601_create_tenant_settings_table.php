<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * tenant_settings — işletme profili (tasarım: "İşletme Profili" ekranı). Bayi başına TEK satır.
 *
 * BİRİNCİL ANAHTAR = tenant_id (surrogate uuid YOK, bilinçli): iki cihaz çevrimdışıyken kendi
 * uuid'siyle profil oluştursaydı unique(tenant_id) ihlali doğar ve bir olay REDDEDİLİRDİ (veri
 * kaybı). tenant_id'yi anahtar yapmak çakışmayı yapısal olarak imkânsız kılar — iki cihazın yazımı
 * AYNI satırda LWW ile birleşir. İstemci payload'a id KOYMAZ; sunucu oturumdaki tenant'ı kullanır.
 *
 * Firma kodu (tasarımdaki "Firma Kodu", değiştirilemez) BURADA DEĞİL: o `tenants.slug`'tur —
 * sunucuya ait kimliktir, istemci yazamaz; senkron yanıtında subscription.tenant_code ile yayınlanır.
 *
 * Tombstone YOK: profil silinmez (bayi varsa profili de vardır). LWW meta senkron için standart.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_settings', function (Blueprint $table) {
            $table->uuid('tenant_id')->primary();
            $table->string('business_name', 160)->nullable();
            $table->string('owner_name', 120)->nullable();
            $table->string('phone', 32)->nullable();
            $table->string('whatsapp', 32)->nullable();
            $table->text('address_text')->nullable();
            $table->string('tax_office', 120)->nullable();
            $table->string('tax_number', 20)->nullable();
            $table->string('opens_at', 5)->nullable();   // 'SS:DD' — çalışma saati, tarih değil
            $table->string('closes_at', 5)->nullable();
            $table->text('receipt_note')->nullable();    // fiş alt notu
            $table->timestampTz('updated_occurred_at')->useCurrent(); // LWW meta
            $table->uuid('updated_device_id')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tenant_settings');
    }
};
