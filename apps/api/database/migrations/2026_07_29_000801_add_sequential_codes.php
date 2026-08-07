<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * SIRA NUMARALARI — müşteri kodu (102) ve sipariş kodu (#248).
 *
 * Kullanıcı isteği (2026-07-29): "her müşterinin bir kodu olmalı, m100 değil 100 101 102 gibi;
 * her siparişin de bir kodu olmalı #xxx gibi". Öncesinde mobilde `musteriKod()` UUID'nin son üç
 * RAKAMINDAN "M-007" üretiyordu — bu bir GÖSTERİMDİ, kimlik değildi: iki müşteri aynı üçlüyü
 * alabiliyordu ve sayı hiçbir sırayı anlatmıyordu.
 *
 * KOD SUNUCUDA ATANIR (istemci ezemez). Deseni `customers.balance_kurus` ile aynıdır: istemciden
 * yazılabilir kolonlar listesinde YOKTUR, sunucu üretir ve senkron değişikliğiyle geri gönderir
 * (`SyncPayload::change` modeli refresh edip serialize ettiği için yeni kolon kendiliğinden akar).
 * Gerekçe: sıra numarası TEK bir dağıtıcı ister. İstemci kendi sayısını üretseydi, iki cihaz
 * çevrimdışıyken aynı numarayı alır ve senkronda biri DEĞİŞTİRİLMEK zorunda kalırdı — bayinin
 * kâğıda yazdığı "#248" ertesi gün başka bir siparişe ait olurdu. Geç gelen bir numara,
 * değişen bir numaradan iyidir (para bitişiğindeki hiçbir kimlik sessizce kaymamalı).
 *
 * 100'DEN BAŞLAR: kullanıcının verdiği örnek (100 101 102). Üç hane, tek bakışta okunur ve
 * "1 numaralı müşteri" gibi anlamsız bir başlangıç yaratmaz.
 *
 * TEKİLLİK KİRACI İÇİNDEDİR (kırmızı çizgi #1): kısmi unique indeks (code IS NOT NULL) — kodu
 * henüz atanmamış satırlar birbirini engellemez.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $t) {
            $t->integer('code')->nullable();
        });
        Schema::table('orders', function (Blueprint $t) {
            $t->integer('code')->nullable();
        });

        // Mevcut kayıtlara geriye dönük kod: kiracı içinde OLUŞMA SIRASINA göre. Sıra
        // created_at'e değil occurred_at'e bakar — kayıtların iş zamanı odur (created_at
        // sunucuya ULAŞMA anıdır ve çevrimdışı bir cihaz onu toplu halde bozar).
        DB::statement(<<<'SQL'
            WITH s AS (
              SELECT id, 99 + ROW_NUMBER() OVER (
                       PARTITION BY tenant_id ORDER BY updated_occurred_at, id
                     ) AS yeni
              FROM customers
            )
            UPDATE customers c SET code = s.yeni FROM s WHERE c.id = s.id
        SQL);

        DB::statement(<<<'SQL'
            WITH s AS (
              SELECT id, 99 + ROW_NUMBER() OVER (
                       PARTITION BY tenant_id ORDER BY occurred_at, id
                     ) AS yeni
              FROM orders
            )
            UPDATE orders o SET code = s.yeni FROM s WHERE o.id = s.id
        SQL);

        DB::statement('CREATE UNIQUE INDEX customers_tenant_code_uniq ON customers (tenant_id, code) WHERE code IS NOT NULL');
        DB::statement('CREATE UNIQUE INDEX orders_tenant_code_uniq ON orders (tenant_id, code) WHERE code IS NOT NULL');

        // Sipariş satırında HANGİ kodun görüneceği bayinin tercihidir (kullanıcı isteği:
        // "isteyen firma siparişte müşteri kodu, isteyen firma sipariş kodu görsün").
        // Varsayılan 'musteri': liste bugün de müşteri kimliğini gösteriyor ve telefonla
        // sipariş alan bir bayide satırda aranan şey müşteridir. Sipariş kodu her hâlükârda
        // sipariş DETAYINDA görünür — ayar yalnız listedeki dar alanı paylaştırır.
        Schema::table('tenant_settings', function (Blueprint $t) {
            $t->string('order_code_display', 16)->default('musteri');
        });
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS customers_tenant_code_uniq');
        DB::statement('DROP INDEX IF EXISTS orders_tenant_code_uniq');
        Schema::table('customers', fn (Blueprint $t) => $t->dropColumn('code'));
        Schema::table('orders', fn (Blueprint $t) => $t->dropColumn('code'));
        Schema::table('tenant_settings', fn (Blueprint $t) => $t->dropColumn('order_code_display'));
    }
};
