<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * KURYE MÜŞTERİ GÖRÜNÜRLÜĞÜ — `courier_can_see_all_customers` (kullanıcı kararı 2026-08-22).
 *
 * ══ NE DEĞİŞİYOR ═══════════════════════════════════════════════════════════════════════════
 * Bugüne kadar kurye, bayinin MÜŞTERİ DEFTERİNİN TAMAMINI görüyordu. `courier_can_customers`
 * vardı ama o "ekleyip düzenleyebilir mi" sorusunu cevaplıyor; listeyi hiç kısıtlamıyordu.
 * Kullanıcının isteği: "kuryenin tüm müşterileri görebilmesi için yetkisinin olması gerekiyor,
 * yoksa sadece siparişi olan müşteriyi görebilir."
 *
 * ══ VARSAYILAN `false` VE BU BİR DAVRANIŞ DEĞİŞİKLİĞİDİR ═══════════════════════════════════
 * Bu depodaki diğer yetkilerin çoğu "bugünkü davranışı koru" diye varsayılanını AÇIK aldı.
 * Burada tersi seçildi ve bilinçli: istek KISITLAMANIN KENDİSİDİR. Varsayılanı `true` yapmak,
 * özelliği isteyen bayinin onu ayrıca kapatmasını gerektirirdi — yani hiç kimse için
 * değişmeyen, yalnız ayar listesini uzatan bir anahtar olurdu.
 *
 * Bedeli açıkça yazılıyor: yükseltmeden sonra kuryenin müşteri listesi DARALIR (yalnız kendi
 * siparişlerinin müşterileri). Bunu isteyen bayi hiçbir şey yapmaz; istemeyen bayi Ayarlar →
 * Kurye Yetkileri'nden tek anahtarla eski davranışa döner. Ters yön (herkese açık başlayıp
 * sonradan kısmak) müşteri verisini gereğinden uzun süre açıkta bırakırdı ve KVKK önünde
 * bayinin sorumluluğu buradadır (BRIEF kırmızı çizgi #4'ün komşuluğu).
 *
 * ══ VERİ SİLİNMEZ, İNMEYE DE DEVAM EDER ════════════════════════════════════════════════════
 * Bu bir SUNUCU SÜZGECİ DEĞİL, GÖRÜNÜRLÜK yetkisidir. Uygulama offline-first çalışır: senkron
 * snapshot'ı bayinin tüm müşterilerini telefona indirir ve indirmeye devam eder. Kısıtlama
 * ekranda uygulanır (`customer_list_screen.dart`), tıpkı `courier_can_see_all_orders`ta
 * olduğu gibi. Sunucu tarafında süzmek, kuryenin ATANDIĞI ilk anda müşterisi henüz inmemiş
 * bir sipariş görmesi demekti — kapıda adres olmayan bir teslim, kırmızı çizgi #3'ün ihlali.
 *
 * ══ ŞEMA ═══════════════════════════════════════════════════════════════════════════════════
 * `tenant_settings` → NOT NULL DEFAULT false (bayi varsayılanı / yeni kurye şablonu)
 * `users`           → NULLABLE (null = "bayi varsayılanını devral"; 004008'in üç durumlu modeli)
 *
 * `sync_changes` deltası GEREKMEZ: `users` her senkronda `team` bloğuyla toptan iner, ve bu
 * migration mevcut `tenant_settings` satırlarının DEĞERİNİ değiştirmiyor — kolon yeni doğuyor,
 * varsayılanıyla. Mobil tarafta karşılığı şema v27'dir; üç yer birlikte güncellendi
 * (uygulayıcının kolon listesi, mobil ayrıştırıcı, mobil migration).
 */
return new class extends Migration
{
    /**
     * Kolon adı BURADA ELLE YAZILIR (004007/004008 deseni): migration bir TARİH KAYDIDIR ve
     * yıllar sonra da bugünkü şemayı üretmelidir. Uygulama sabitine bağlansaydı, listeye
     * yarın eklenen bir yetki bu migration'ın geçmişini geriye dönük değiştirirdi.
     */
    private const KOLON = 'courier_can_see_all_customers';

    public function up(): void
    {
        Schema::table('tenant_settings', function (Blueprint $table) {
            $table->boolean(self::KOLON)->default(false);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->boolean(self::KOLON)->nullable()->default(null);
        });
    }

    public function down(): void
    {
        Schema::table('tenant_settings', function (Blueprint $table) {
            $table->dropColumn(self::KOLON);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(self::KOLON);
        });
    }
};
