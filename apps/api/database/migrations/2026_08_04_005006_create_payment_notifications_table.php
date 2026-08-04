<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * "HAVALE GÖNDERDİM" BİLDİRİMİ — bayinin SİTEDEN yaptığı ödeme beyanı (tasarım `14-sw-hesap.jsx`:
 * "Açıklama alanına referans kodunuzu yazın; dekont ulaştığı gün dönem uzatılır").
 *
 * NEDEN AYRI TABLO, NEDEN subscription_payments'a YAZMIYORUZ: `subscription_payments` PARANIN
 * kaydıdır — oradaki bir `success` satırı aboneliği uzatır. Bayinin beyanı ise bir İDDİAdır; para
 * hesaba geçmiş olabilir de olmayabilir de. İkisini aynı tabloya koymak, "gönderdim" diyen herkesin
 * kendi aboneliğini uzatabilmesi demekti. Beyan burada bekler; biz banka ekstresinde görünce
 * PANELDEN eşleştiririz ve GERÇEK ödeme kaydı o zaman (owner ile, OdemeKayitServisi) oluşur.
 *
 * BU YÜZDEN APPEND-ONLY DEĞİLDİR: satırın kendisi bir DURUM makinesidir
 * (pending → matched | rejected) ve kapanışın kim/ne zaman bilgisini taşır. Doğurduğu para kaydı
 * (`subscription_payment_id`) append-only tarafta durur; beyanın güncellenmesi para geçmişini
 * ezmez. Kapanmış bir bildirim yeniden açılmaz (CHECK: resolved_at ve status birlikte tutarlı).
 *
 * BAĞLANTI: INSERT'ü SİTE yapar (`pgsql_owner` — public sitede panel rolü yoktur ve sipario_app'in
 * bu tabloda izni bilinçli olarak YOKtur, bkz. 005010); eşleştirme/reddetme de owner ile, çünkü
 * ödeme kaydı + tenant uzatma + bildirim kapanışı TEK transaction olmak zorundadır.
 *
 * KVKK: dekont görseli/IBAN/kart verisi TUTULMAZ. Yalnız beyan edilen tutar, yöntem, bayinin
 * yazdığı referans kodu ve tarih.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payment_notifications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->bigInteger('amount_kurus');
            $table->string('method', 10);                 // iban | elden
            $table->string('reference_code', 40);
            $table->date('declared_on');
            $table->string('status', 10)->default('pending');   // pending | matched | rejected
            $table->uuid('subscription_payment_id')->nullable();
            $table->text('note')->nullable();
            $table->timestampTz('created_at')->useCurrent();
            $table->timestampTz('resolved_at')->nullable();
            $table->uuid('resolved_by_admin_id')->nullable();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign('subscription_payment_id')->references('id')->on('subscription_payments')->nullOnDelete();
            $table->index(['status', 'created_at']);
            $table->index(['tenant_id', 'created_at']);
            $table->index('reference_code');
        });

        DB::statement(
            'ALTER TABLE payment_notifications ADD CONSTRAINT payment_notifications_status_check '.
            "CHECK (status IN ('pending','matched','rejected'))"
        );
        DB::statement(
            'ALTER TABLE payment_notifications ADD CONSTRAINT payment_notifications_method_check '.
            "CHECK (method IN ('iban','elden'))"
        );
        DB::statement(
            'ALTER TABLE payment_notifications ADD CONSTRAINT payment_notifications_amount_check '.
            'CHECK (amount_kurus > 0)'
        );
        // Durum ile kapanış damgası AYRIŞAMAZ: 'pending' satırda resolved_at olamaz, kapanmış
        // satırda resolved_at zorunludur. Yoksa "çözüldü ama ne zaman bilinmiyor" satırları birikir.
        DB::statement(
            'ALTER TABLE payment_notifications ADD CONSTRAINT payment_notifications_resolved_check '.
            "CHECK ((status = 'pending' AND resolved_at IS NULL) OR (status <> 'pending' AND resolved_at IS NOT NULL))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_notifications');
    }
};
