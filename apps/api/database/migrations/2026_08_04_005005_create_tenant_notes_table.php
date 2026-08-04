<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * BAYİ NOTLARI — panelden tutulan satış/destek notu (tasarım `07-Uyeler.jsx`, firma detayındaki
 * "notlar" listesi: "Telefonla arandı, haftaya ödeyecek.").
 *
 * APPEND-ONLY. Not, bir konuşmanın tutanağıdır; sonradan düzenlenirse tutanak olmaktan çıkar.
 * "Yanlış yazdım" durumunun karşılığı yeni bir nottur.
 *
 * NEDEN panel_audit DEĞİL: `panel_audit` KVKK-nötr bir EYLEM günlüğüdür ve içine serbest metin
 * yazılmaz (kırmızı çizgi #4 gereği yalnız eylem türü + hedef id). Bu tablo ise bilerek serbest
 * metindir. İkisini karıştırmak, denetim günlüğüne kişisel veri sızdırmanın en kolay yoluydu.
 *
 * BAYİYE GÖSTERİLMEZ: sipario_app'in bu tabloda hiçbir izni yoktur (005010). Not bizim iç
 * kaydımızdır; bayi kendisi hakkında ne yazdığımızı hesap panelinden GÖREMEZ.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_notes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('admin_user_id')->nullable();
            $table->text('body');
            $table->timestampTz('created_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->index(['tenant_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tenant_notes');
    }
};
