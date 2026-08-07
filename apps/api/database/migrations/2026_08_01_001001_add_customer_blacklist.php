<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * KARA LİSTE — customers.blacklisted_at (null = kara listede değil).
 *
 * NEDEN AYRI BİR SÜTUN, `deleted_at` DEĞİL: bunlar iki farklı karardır ve saha ikisini de
 * kullanır. "Sil" müşteriyi listeden kaldırır (tombstone, zaten var); "kara liste" müşteriyi
 * listede TUTAR ve yalnız yeni sipariş almayı durdurur — bayi ödemeyen müşteriyi gözden
 * kaybetmek istemez, tam tersine görünür kalsın ki borcunu takip etsin.
 *
 * NEDEN BOOLEAN DEĞİL, TIMESTAMP: "ne zaman kara listeye alındı" bilgisi bedavaya gelir ve
 * `deleted_at` ile aynı biçimi paylaşır — LWW ile senkronlanan iki alan aynı desende olsun.
 * Ayrıca null/dolu ayrımı üç-durumlu (bilinmiyor) tuzağına düşmez.
 *
 * SİLME İÇİN MIGRATION YOK: `customers.deleted_at` Faz 2'den beri var ve senkronun `delete`
 * op'u (ChangeApplier::applySimpleEntity) tombstone'u zaten yazıyor. Silme özelliği sunucuda
 * yeni ŞEMA değil, yeni İSTEMCİ yüzeyidir.
 *
 * GERİYE DÖNÜK SENKRON YAYINI GEREKMEZ (migration 802'nin dersi burada tetiklenmiyor): bu
 * migration hiçbir satırın DEĞERİNİ değiştirmiyor, yalnız null bir sütun ekliyor. 802'deki arıza
 * mevcut satırlara VERİ yazılıp istemciye ulaşmamasıydı; burada ulaşacak veri yok. Bir müşteri
 * kara listeye ilk alındığında normal push/pull yolundan zaten inecek.
 *
 * RLS: customers tablosu Faz 2'den beri ENABLE+FORCE RLS; policy ve GRANT tablo düzeyindedir,
 * yeni sütun otomatik kapsanır (kolon düzeyinde yetki kullanılmıyor).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            $table->timestampTz('blacklisted_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('customers', fn (Blueprint $t) => $t->dropColumn('blacklisted_at'));
    }
};
