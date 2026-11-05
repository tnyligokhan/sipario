<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * SAHA LİSTESİNİN (2026-11-05) ÜÇ ŞEMA İHTİYACI — mobil 1.15.0.
 *
 *  · `order_lines.discount_kurus` — SATIR İSKONTOSU ("ürün eklenirken iskonto eklenemiyor"). Satırın
 *    tamamından düşülen tutar. `line_total_kurus = unit_price * qty - discount_kurus` olur; sipariş
 *    toplamı zaten satır toplamlarından türediği için teslim, defter ve gün sonu hesabı DEĞİŞMEZ.
 *    Kapıda iskontodan (`ledger_entries.discount`) AYRIDIR: o, teslimde kırılan borçtur; bu, satışın
 *    baştan indirimli yapılmasıdır ve deftere hiç borç olarak girmez.
 *
 *  · `customers.product_prices` — MÜŞTERİYE ÖZEL BİRİM FİYAT, ürün kimliği → kuruş. Ayrı senkron
 *    varlığı DEĞİL, müşterinin bir ALANI (`product_options` ile aynı gerekçe ve aynı sözleşme: anahtar
 *    payload'da HİÇ YOKSA mevcut değer korunur). Fiyat sipariş anında satıra kopyalanır, yani bu
 *    alanın değişmesi eski siparişleri etkilemez.
 *
 *  · `tenant_settings.expense_categories` — BAYİNİN GİDER KATEGORİLERİ (metin listesi). null =
 *    bayi hiç düzenlemedi, istemci varsayılan listeyi gösterir.
 *
 * ESKİ İSTEMCİ: üçünü de bilmez ve çalışmaya devam eder (MINOR). `discount_kurus` göndermeyen satır
 * 0 iskontolu sayılır; pull'da satır toplamını sunucudan aldığı için tutarı doğru görür.
 *
 * RLS: üç tablo da ENABLE+FORCE RLS; policy ve GRANT tablo düzeyindedir, yeni sütunlar kapsanır.
 * Migration owner (sipario_owner) ile koşar: `artisan migrate --database=pgsql_owner --force`.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('order_lines', function (Blueprint $t) {
            $t->bigInteger('discount_kurus')->default(0);
        });
        DB::statement(
            'ALTER TABLE order_lines ADD CONSTRAINT order_lines_discount_check CHECK (discount_kurus >= 0)'
        );

        Schema::table('customers', function (Blueprint $t) {
            $t->json('product_prices')->nullable();
        });

        Schema::table('tenant_settings', function (Blueprint $t) {
            $t->json('expense_categories')->nullable();
        });
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE order_lines DROP CONSTRAINT IF EXISTS order_lines_discount_check');
        Schema::table('order_lines', fn (Blueprint $t) => $t->dropColumn('discount_kurus'));
        Schema::table('customers', fn (Blueprint $t) => $t->dropColumn('product_prices'));
        Schema::table('tenant_settings', fn (Blueprint $t) => $t->dropColumn('expense_categories'));
    }
};
