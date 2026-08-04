<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * subscription_payments — ELLE ÖDEME (IBAN/havale + elden) için genişletme. Tablo APPEND-ONLY KALIR
 * (RLS + REVOKE 000506 aynen geçerli); yalnız satırın taşıdığı bilgi zenginleşiyor.
 *
 * NEDEN AYRI "manuel ödemeler" TABLOSU AÇILMADI: gelir GELİRDİR. Aylık gelir raporu (tasarım
 * `GelirGider`) iki tabloyu toplamak zorunda kalsaydı, biri unutulduğunda rapor sessizce eksik
 * çıkardı — ve yanlış olduğu ancak yıl sonunda anlaşılırdı. Abonelik ödemesi, ek paket geliri ve
 * (ertelenen) iyzico tahsilatı TEK tablodadır; ayrımı `provider` + `period` kolonları yapar.
 *
 * `provider`: bugüne kadar kısıtsızdı ve pratikte yalnız 'iyzico'/'fake' yazılıyordu. Elle ödeme
 * yollarıyla birlikte küme anlamlı hâle geldiği için CHECK ile SABİTLENİYOR — yazım hatası bir
 * ödemeyi rapordan düşürmesin ('IBAN' ile 'iban' iki ayrı sağlayıcı sayılmasın).
 *   iban | elden → panelden/siteden elle kaydedilen tahsilat
 *   iyzico       → ERTELENDİ ama yol SİLİNMEDİ (IyzicoPaymentGateway duruyor)
 *   fake         → testlerin sahte sağlayıcısı
 *
 * `period`: 'monthly' | 'yearly' | 'addon'. Aboneliğin hangi dönemi uzattığını ve satırın bir EK
 * PAKET geliri olduğunu ayırt eder. NULLABLE: geçmiş satırlar (iyzico yıllık) için geriye dönük
 * doldurma aşağıda yapılıyor, ama 'initiated'/'failed' satırlarında dönem anlamsız kalabilir.
 *
 * `covers_period`: insan okur ("Ağustos 2026", "Ek paket · 250 oto-sıralama hakkı"). Tasarımın
 * ödemeler tablosundaki "Dönem" sütunu budur; TÜRETİLMEZ çünkü elden alınan bir ödeme hangi ayı
 * kapattığını yalnız operatörün bildiği bir bilgidir (Temmuz'da ödenen Ağustos aboneliği).
 *
 * `recorded_by_admin_id`: kaydı hangi panel yöneticisi girdi. Elle para kaydı, panelin en hassas
 * yetkisidir; panel_audit'e eylem düşer ama satırın kendisi de kimin girdiğini taşımalı.
 *
 * GERİYE DÖNÜK DOLDURMA: mevcut success satırları iyzico yıllık akıştan gelmiştir → period='yearly'.
 * Değer değişiyor ama SENKRONA DÜŞÜRÜLMEZ: subscription_payments telefona ASLA inmez (mobilde
 * fiyat/ödeme gösterilemez — mağaza kuralı, BRIEF pazarlıksız maddesi). Migration 802'nin dersi
 * "istemciye ulaşması gereken değer" içindir; bu değerin istemcide işi yok.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('subscription_payments', function (Blueprint $table) {
            $table->string('covers_period', 60)->nullable();
            $table->string('period', 10)->nullable();
            $table->text('note')->nullable();
            $table->uuid('recorded_by_admin_id')->nullable();
        });

        DB::statement(
            'ALTER TABLE subscription_payments ADD CONSTRAINT subscription_payments_period_check '.
            "CHECK (period IS NULL OR period IN ('monthly','yearly','addon'))"
        );
        DB::statement(
            'ALTER TABLE subscription_payments ADD CONSTRAINT subscription_payments_provider_check '.
            "CHECK (provider IN ('iban','elden','iyzico','fake'))"
        );

        DB::statement("UPDATE subscription_payments SET period = 'yearly' WHERE period IS NULL AND status = 'success'");

        // Gelir raporu ay + durum üzerinden tarar; bu indeks olmadan her ekran açılışı tam tarama olur.
        DB::statement(
            'CREATE INDEX subscription_payments_income ON subscription_payments (status, occurred_at)'
        );
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
            DROP INDEX IF EXISTS subscription_payments_income;
            ALTER TABLE subscription_payments DROP CONSTRAINT IF EXISTS subscription_payments_period_check;
            ALTER TABLE subscription_payments DROP CONSTRAINT IF EXISTS subscription_payments_provider_check;
        SQL);

        Schema::table('subscription_payments', function (Blueprint $table) {
            $table->dropColumn(['covers_period', 'period', 'note', 'recorded_by_admin_id']);
        });
    }
};
