<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * tenants — yeni panel/site alanları.
 *
 * `contact_name` / `city` / `district`: tasarım `07-Uyeler.jsx` firma listesini "Firma, yetkili
 * veya il" ile aratıyor ve satırın altına "İl / İlçe" yazıyor. Bugün bu üç bilgi HİÇBİR YERDE
 * yok — birebir satışta kazanılan bayinin yetkilisini ve şehrini yalnız satışı yapan kişi bilir.
 *
 * `courier_limit`: kurye hesabı kotası. Bugün kota YOKtu; "3 kurye hesabı" yalnız fiyat
 * sayfasındaki bir CÜMLEydi ve hiçbir yerde zorlanmıyordu (App\Abonelik\KuryeKotasi bu kolonu
 * okur). Varsayılan 3 = plan tohumu; ek paket tanımlaması bu sayıyı ARTIRIR.
 *
 * `billing_period`: aylık mı yıllık mı abone. Ödeme kaydedildiğinde `valid_until`ın +1 ay mı +1 yıl
 * mı uzayacağını BU alan belirler. NULL = henüz abone olmamış (deneme) — bu yüzden CHECK NULL'a
 * izin verir; "monthly'yi varsayılan yapalım" denmedi, çünkü o zaman hiç ödeme yapmamış bir denemeci
 * ekranlarda "aylık abone" görünürdü.
 *
 * SENKRON DELTASI (migration 802'nin dersi — bilinçli değerlendirildi):
 *  - `tenants` bir senkron VARLIĞI DEĞİLDİR; sync_changes'e satır düşmez. Bayinin telefonunun
 *    gördüğü tenant alanları `SyncService::subscriptionPayload` ile HER senkronda TAM DURUM olarak
 *    yayınlanır (delta değil). Yani yeni kolonun telefona ulaşması için delta üretmek değil,
 *    kolonu O BLOĞA EKLEMEK gerekir.
 *  - `courier_limit` bu yüzden aynı vardiyada `subscriptionPayload`a eklendi (route_credits_monthly
 *    ile birebir aynı kanal, aynı gerekçe: sunucu-sahipli, istemcinin yazamayacağı kota).
 *  - `contact_name` / `city` / `district` / `billing_period` telefona İNMEZ ve inmemelidir: bunlar
 *    bizim satış/faturalama kayıtlarımızdır, sahadaki uygulamanın hiçbir ekranı bunları kullanmaz
 *    (mağaza kuralı gereği mobilde abonelik/dönem/fiyat bilgisi zaten GÖSTERİLEMEZ).
 *  - Hiçbir MEVCUT satırın değeri değişmiyor (yalnız null kolonlar + sabit varsayılan) → geriye
 *    dönük yayın gerekmez.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->string('contact_name', 120)->nullable();
            $table->string('city', 60)->nullable();
            $table->string('district', 60)->nullable();
            $table->integer('courier_limit')->default(3);
            $table->string('billing_period', 10)->nullable();
        });

        DB::statement(
            'ALTER TABLE tenants ADD CONSTRAINT tenants_billing_period_check '.
            "CHECK (billing_period IS NULL OR billing_period IN ('monthly','yearly'))"
        );
        DB::statement(
            'ALTER TABLE tenants ADD CONSTRAINT tenants_courier_limit_check CHECK (courier_limit >= 0)'
        );
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_billing_period_check');
        DB::statement('ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_courier_limit_check');

        Schema::table('tenants', function (Blueprint $table) {
            $table->dropColumn(['contact_name', 'city', 'district', 'courier_limit', 'billing_period']);
        });
    }
};
