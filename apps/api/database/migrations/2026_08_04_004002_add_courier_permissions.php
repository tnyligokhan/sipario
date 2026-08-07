<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * KURYE YETKİLERİ — bayinin açıp kapatabildiği beş anahtar (kullanıcı isteği 2026-08-04:
 * "kuryenin hangi bilgilerde değişiklik yapabileceği … bir on-off şeklinde bir şey olmalı").
 *
 * NEDEN KİRACI DÜZEYİNDE, KULLANICI BAŞINA DEĞİL: bayi 1–3 kişidir (BRIEF). Kurye başına yetki
 * yönetimi kurulum sürtünmesidir (korku #3) ve daha kötüsü, her yeni kuryede UNUTULAN bir adım
 * doğurur — "yeni çocuk neden tahsilat alamıyor?" diye aranan bir destek çağrısı. Esnafın zihin
 * modeli "kuryelerim şunu yapabilir"dir, "Ali şunu, Veli bunu" değil. Kişiselleştirme gerekirse
 * bu satırlar kullanıcı düzeyine TAŞINABİLİR; tersi (kişiselden ortağa dönmek) veri kaybettirirdi.
 *
 * NEDEN JSON DEĞİL, BEŞ AYRI BOOLEAN: şema kendini anlatır, senkron beyaz listesi doğal olarak
 * kolon listesidir ve istemci tarafında ayrıştırma yoktur. JSON tek kolon kazandırırdı ama
 * tanınmayan anahtarları elemek için ayrı bir beyaz liste koduna ihtiyaç duyardı (order_code_display
 * dersinin daha karmaşık hâli).
 *
 * VARSAYILANLAR SAHA GERÇEĞİNDEN: kurye zaten müşteri kaydeder, sipariş açar ve para tahsil eder —
 * işini yapamayan bir kurye ürünü kullanılmaz kılar, o yüzden üçü AÇIK doğar. İskonto (para kırma)
 * ve gün sonu (bayinin kasa özeti) KAPALI doğar: ikisi de patron kararıdır ve varsayılanı açık
 * bırakmak, kimsenin istemediği bir yetkiyi sessizce vermek olurdu.
 *
 * MEVCUT KURULUMLAR: DEFAULT değerleri sayesinde her satır anlamlı bir değerle doğar; bu, bugüne
 * kadarki DAVRANIŞLA da uyumludur (kurye tahsilat alabiliyordu, iskonto/gün sonu göremiyordu).
 * Yani migration hiçbir bayinin bugünkü deneyimini değiştirmez — yalnız anahtarı görünür kılar.
 */
return new class extends Migration
{
    /** Kolon → varsayılan. Aşağıda hem up() hem down() bunu kullanır. */
    private const KOLONLAR = [
        'courier_can_customers' => true,   // müşteri ekle/düzenle
        'courier_can_orders' => true,      // sipariş oluştur
        'courier_can_collect' => true,     // tahsilat al
        'courier_can_discount' => false,   // kapıda iskonto (para kırma)
        'courier_can_day_end' => false,    // gün sonu özetini gör
    ];

    public function up(): void
    {
        Schema::table('tenant_settings', function (Blueprint $table) {
            foreach (self::KOLONLAR as $kolon => $varsayilan) {
                $table->boolean($kolon)->default($varsayilan);
            }
        });
    }

    public function down(): void
    {
        Schema::table('tenant_settings', function (Blueprint $table) {
            $table->dropColumn(array_keys(self::KOLONLAR));
        });
    }
};
