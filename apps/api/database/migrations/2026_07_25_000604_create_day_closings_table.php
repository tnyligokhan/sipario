<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * day_closings — gün sonu KAPANIŞ ARŞİVİ (tasarım: "Gün Sonu → Hesabı Kapat" + "Arşiv"). Faz 3'te
 * gün sonu salt-okunur bir read-model'di; tasarım kalıcı bir kapanış kaydı istiyor: kapatılan hesap
 * kilitlenir ve arşivde kuruşu kuruşuna geri okunur.
 *
 * APPEND-ONLY (kırmızı çizgi #2, cash_handovers 403/405 deseni): kapanış bir mutabakat kanıtıdır;
 * UPDATE/DELETE yetkisi migration 607'de geri alınır. Yanlış kapanış YENİ kapanış kaydıyla düzeltilir.
 *
 * scope='courier' → user_id kuryedir; scope='day' → user_id NULL (günün tamamı).
 *
 * ÖZET ALANLARI KASTEN SATIRDA SAKLANIR (order_lines.unit_price deseni): arşiv, kapatıldığı ANDAKİ
 * gerçeği taşır. Sonradan gelen geç senkron kayıtları bugünün toplamını değiştirebilir; arşiv
 * değişmemelidir, yoksa "kapatıldı" ifadesi anlamını yitirir.
 *
 * counted/expected/diff İSTEMCİ SNAPSHOT'ıdır (cash_handovers ile aynı güven modeli). cash_handover_id
 * kapanışla birlikte yazılan kasa devrine bağlar (kurye kapanışında); para mutabakatının defteri hâlâ
 * cash_handovers'tır, day_closings o anın ekran özetidir.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('day_closings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->string('scope', 10);                    // day|courier (CHECK aşağıda)
            $table->uuid('user_id')->nullable();            // kurye (scope=courier); day'de NULL
            $table->timestampTz('period_start')->nullable();
            $table->integer('delivery_count')->default(0);
            $table->bigInteger('total_collected_kurus')->default(0); // nakit+kart+havale
            $table->bigInteger('cash_nakit_kurus')->default(0);
            $table->bigInteger('cash_kart_kurus')->default(0);
            $table->bigInteger('cash_havale_kurus')->default(0);
            $table->bigInteger('open_credit_kurus')->default(0);     // o anki açık veresiye toplamı
            $table->bigInteger('expected_cash_kurus')->default(0);
            $table->bigInteger('counted_cash_kurus')->nullable();    // sayılmadıysa null
            $table->bigInteger('diff_kurus')->default(0);            // counted − expected (KANIT)
            $table->uuid('cash_handover_id')->nullable();
            $table->text('note')->nullable();
            $table->timestampTz('occurred_at')->useCurrent();
            $table->uuid('device_id')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'id']);
            $table->index(['tenant_id', 'occurred_at']);
        });

        DB::statement(
            'ALTER TABLE day_closings ADD CONSTRAINT day_closings_scope_check '.
            "CHECK (scope IN ('day','courier'))"
        );
        // scope ile user_id tutarlılığı: kurye kapanışı kullanıcısız, gün kapanışı kullanıcılı olamaz.
        DB::statement(
            'ALTER TABLE day_closings ADD CONSTRAINT day_closings_scope_user_check '.
            "CHECK ((scope = 'day' AND user_id IS NULL) OR (scope = 'courier' AND user_id IS NOT NULL))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('day_closings');
    }
};
