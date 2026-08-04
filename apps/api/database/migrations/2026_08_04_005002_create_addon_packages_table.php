<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * EK PAKETLER — satıştaki katalog (tasarım `09-PlanDuzenleModal.jsx` · "Ek Paketler" kartı).
 * İki tür vardır ve ikisi de SUNUCUDA ZORLANAN bir kotayı büyütür:
 *  - credits → `tenants.route_credits` (oto-sıralama hakkı; RouteController kontörü düşer)
 *  - courier → `tenants.courier_limit` (açılabilecek kurye hesabı sayısı; App\Abonelik\KuryeKotasi)
 *
 * NEDEN SİLME YOK (`active` bayrağı var): satılmış bir paket, geçmiş tanımlamalarda referanslıdır.
 * Tasarım da "Satışta / Pasif" rozetiyle bunu söylüyor — satırı silmek gelir geçmişini okunamaz
 * hâle getirirdi. `addon_grants` paketin ADINI da kopyalar, böylece paket bir gün silinse bile
 * eski tanımlama "Silinmiş paket" demez.
 *
 * PARA: imzasız int KURUŞ, bigint (plans ile aynı gerekçe).
 *
 * TOHUM tasarımdaki katalogtur (`03-BUGUN.jsx` ILK_PAKETLER): 1000'lik paket bilerek PASİF gelir —
 * "Satışta değil" durumunun boş ekranla değil gerçek veriyle sınanabilmesi için.
 *
 * SENKRON: bu tablo telefona İNMEZ (şirket kataloğu). Bayinin gördüğü tek şey tanımlama SONRASI
 * artan kotasıdır ve o, abonelik bloğuyla iner.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('addon_packages', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('type', 10);           // credits | courier
            $table->string('name', 120);
            $table->integer('quantity');
            $table->bigInteger('price_kurus');
            $table->boolean('active')->default(true);
            $table->timestampsTz();

            $table->index(['active', 'type']);
        });

        DB::statement(
            'ALTER TABLE addon_packages ADD CONSTRAINT addon_packages_type_check '.
            "CHECK (type IN ('credits','courier'))"
        );
        DB::statement(
            'ALTER TABLE addon_packages ADD CONSTRAINT addon_packages_amounts_check '.
            'CHECK (quantity > 0 AND price_kurus >= 0)'
        );

        $now = now();
        $tohum = [
            ['credits', '100 oto-sıralama hakkı', 100, 14900, true],
            ['credits', '250 oto-sıralama hakkı', 250, 29900, true],
            ['credits', '500 oto-sıralama hakkı', 500, 49900, true],
            ['credits', '1000 oto-sıralama hakkı', 1000, 84900, false],
            ['courier', '+1 kurye hesabı', 1, 7900, true],
            ['courier', '+3 kurye hesabı', 3, 19900, true],
        ];

        foreach ($tohum as [$tur, $ad, $adet, $kurus, $aktif]) {
            DB::table('addon_packages')->insert([
                'id' => (string) Str::uuid7(),
                'type' => $tur,
                'name' => $ad,
                'quantity' => $adet,
                'price_kurus' => $kurus,
                'active' => $aktif,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('addon_packages');
    }
};
