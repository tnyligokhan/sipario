<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * call_logs — çağrı günlüğü (tasarım: "Son Aramalar", ARAMALAR). Gelen/cevapsız/giden çağrılar,
 * eşleşen müşteri ve sonucu ("Sipariş alındı", "Kayıtsız numara").
 *
 * SENKRONLANIR (karar): çok cihazlı bayide patron, operatörün/kuryenin aldığı çağrıları görmek
 * ister — cihaz-yerel kalsaydı "Son Aramalar" her cihazda farklı olurdu ve gün içi kullanım
 * (churn sinyali) ölçülemezdi. KVKK: telefon numarası zaten customer_phones'ta TR sunucuda duruyor,
 * yeni bir veri sınırı AÇILMIYOR; loglara/crash raporlarına ASLA yazılmaz (kırmızı çizgi #4).
 *
 * APPEND-ONLY DEĞİL (bilinçli): `outcome` ve `customer_id` çağrıdan SONRA zenginleşir (kart üzerinden
 * sipariş açılınca sonuç yazılır) ve bu bir PARA/HAREKET kaydı değildir — kırmızı çizgi #2'nin kapsamı
 * defter/kupon/olay tablolarıdır. Bu yüzden standart LWW + tombstone deseni kullanılır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('call_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('customer_id')->nullable();      // eşleşen müşteri (kayıtsız numarada null)
            $table->string('phone_e164', 32);
            $table->string('phone_last10', 10);
            $table->string('direction', 10);              // incoming|missed|outgoing (CHECK aşağıda)
            $table->text('outcome')->nullable();          // "Sipariş alındı" gibi serbest sonuç
            $table->uuid('related_order_id')->nullable(); // çağrıdan doğan sipariş (varsa)
            $table->timestampTz('occurred_at')->useCurrent();
            $table->uuid('device_id')->nullable();
            $table->timestampTz('updated_occurred_at')->useCurrent(); // LWW meta
            $table->uuid('updated_device_id')->nullable();
            $table->timestampTz('deleted_at')->nullable();            // tombstone
            $table->timestampsTz();

            // Doğrudan tenant FK: customer_id NULL olan (kayıtsız numara) satırlar da tenant silinince
            // temizlensin (composite FK MATCH SIMPLE null'da atlanır — orders deseni).
            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'customer_id'])
                ->references(['tenant_id', 'id'])->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'occurred_at']);
            $table->index(['tenant_id', 'phone_last10']);
        });

        DB::statement(
            'ALTER TABLE call_logs ADD CONSTRAINT call_logs_direction_check '.
            "CHECK (direction IN ('incoming','missed','outgoing'))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('call_logs');
    }
};
