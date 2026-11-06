<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * BİLGİLENDİRME MESAJLARI (kullanıcı isteği 2026-11-06) — mobil 1.16.0.
 *
 * `tenant_settings.message_templates`: bayinin değiştirdiği hazır metinler ve kendi eklediği
 * mesajlar. Ayrı senkron varlığı DEĞİL, ayar satırının bir ALANI (`expense_categories` ile aynı
 * gerekçe ve aynı sözleşme: anahtar payload'da HİÇ YOKSA mevcut değer korunur). Doğrulama
 * `App\Support\Sync\MesajSablonlari`.
 *
 * ESKİ İSTEMCİ: alanı bilmez ve çalışmaya devam eder (MINOR).
 *
 * RLS: tablo ENABLE+FORCE RLS; policy ve GRANT tablo düzeyindedir, yeni sütun kapsanır.
 * Migration owner (sipario_owner) ile koşar: `artisan migrate --database=pgsql_owner --force`.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenant_settings', function (Blueprint $t) {
            $t->json('message_templates')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('tenant_settings', fn (Blueprint $t) => $t->dropColumn('message_templates'));
    }
};
