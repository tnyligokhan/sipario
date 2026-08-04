<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * ABONELİK PLANI — panelden düzenlenebilen TEK satır (tasarım `09-PlanDuzenleModal.jsx`: "tek plan").
 *
 * NEDEN TABLO, NEDEN CONFIG DEĞİL: fiyat bir İŞ kararıdır ve deploy beklemez. Bugün fiyat
 * `config/subscription.php` içinde env'den okunuyor; onu değiştirmek sunucuya girmeyi ve süreci
 * yeniden başlatmayı gerektiriyor. Panelin "Planı Düzenle" ekranı bu satırı yazar, site ve checkout
 * buradan okur (App\Abonelik\PlanDeposu). Config artık YALNIZ YEDEKtir (satır yoksa/okunamazsa).
 *
 * NEDEN TEK SATIR ZORLANIYOR: iki plan satırı sessiz bir felakettir — site bir fiyatı, panel
 * diğerini gösterir ve hangisinin doğru olduğu aylarca fark edilmez. `(true)` üzerine kurulan
 * kısmi olmayan tekil indeks, ikinci INSERT'ü DB seviyesinde reddeder (kod disiplinine bırakılmaz).
 *
 * PARA: İMZASIZ int KURUŞ, bigint (subscription_payments.amount_kurus geleneği). int4 SEÇİLMEDİ:
 * 598800 bugün rahat sığar ama sınırı örneğe göre seçmek bu depoda bir kez pahalıya patladı —
 * para kolonları istisnasız bigint.
 *
 * TOHUM (OKU-BENI.md "bilinen çelişkiler" kararı): 599 ₺/ay · 4.988... → yıllık 5.988 ₺ (598800
 * kuruş, ayda 499 ₺), deneme 30 GÜN (BRIEF kazanır; tasarımdaki 14 gün YANLIŞTIR), aylık 50
 * oto-sıralama hakkı, 3 kurye hesabı.
 *
 * SENKRON DELTASI GEREKMEZ (migration 802'nin dersi burada tetiklenmiyor): `plans` telefona İNMEZ.
 * Mobilin gördüğü kota alanları `tenants.route_credits_monthly` / `tenants.courier_limit`tir ve
 * onlar abonelik bloğuyla HER senkronda baştan yayınlanır (delta değil, tam durum) — plan satırını
 * değiştirmek mevcut bayilerin tenant kolonlarını GEÇMİŞE DÖNÜK değiştirmez, bilinçlidir: fiyat/kota
 * değişikliği yalnız bundan sonraki kayıtlara ve tanımlamalara uygulanır (tasarımın modal notu:
 * "Yeni ücret bundan sonra girilecek ödemelerde varsayılan olur; geçmiş kayıtlar değişmez").
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('plans', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name', 80);
            $table->bigInteger('price_monthly_kurus');
            $table->bigInteger('price_yearly_kurus');
            $table->integer('trial_days')->default(30);
            $table->integer('route_credits_monthly')->default(50);
            $table->integer('courier_limit')->default(3);
            $table->timestampTz('updated_at')->useCurrent();
        });

        DB::statement(
            'ALTER TABLE plans ADD CONSTRAINT plans_amounts_check '.
            'CHECK (price_monthly_kurus >= 0 AND price_yearly_kurus >= 0 AND trial_days >= 0 '.
            'AND route_credits_monthly >= 0 AND courier_limit >= 0)'
        );

        // TEK SATIR emniyeti: sabit bir ifade üzerinde tekil indeks → ikinci satır 23505 ile reddedilir.
        DB::statement('CREATE UNIQUE INDEX plans_single_row ON plans ((true))');

        DB::table('plans')->insert([
            'id' => (string) Str::uuid7(),
            'name' => 'Sipario',
            'price_monthly_kurus' => 59900,
            'price_yearly_kurus' => 598800,
            'trial_days' => 30,
            'route_credits_monthly' => 50,
            'courier_limit' => 3,
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('plans');
    }
};
