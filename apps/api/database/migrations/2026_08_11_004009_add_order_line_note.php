<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * SEPET SATIRI NOTU — order_lines.note (kullanıcı isteği 2026-08-11).
 *
 * NEDEN SATIRDA, `orders.note` DEĞİL: sipariş notu ("kapıya bırak") siparişin TAMAMINA aittir ve
 * Faz 2'den beri var. Bayinin istediği bundan farklı: sepetteki HER ÜRÜNE ayrı not ("bu damacana
 * buzlu olsun", "şu ikisi ayrı poşete"). Sipariş notuna yığmak iki bilgiyi tek metinde eritir ve
 * kurye hangi notun hangi ürüne ait olduğunu ancak tahmin ederdi. `unit`/`product_name`/
 * `unit_price_kurus` ile AYNI desen: satırın çekildiği andaki gerçeği satır taşır.
 *
 * NEDEN 500 KARAKTER: tek bir ürüne düşülen not için fazlasıyla geniş, ama sınırsız değil —
 * sınırsız bir kolon, hatalı bir istemci ya da yapıştırılan bir belge yüzünden senkron partisine
 * megabaytlar taşıyabilirdi (bir siparişte ONLARCA satır olabilir; sipariş notunun aksine bu alan
 * ÇARPILIR). Sınır UYGULAYICIDA da kontrol edilir (OrderChangeApplier::satirNotu): kolon sınırına
 * dayanıp 22001 almak TÜM partiyi düşürürdü; uygulayıcıdan fırlayan istisna savepoint ile yalnız
 * BU olayı 'rejected' işaretler ve partinin geri kalanı yazılır (`iban`/`reminder_template` deseni).
 * Kırpma YOK: yarım kalan bir not kuryeye yanlış talimat verir.
 *
 * NULLABLE: notu olmayan satır kuraldır, istisna değil. Boş metin `null`a indirgenir (uygulayıcıda)
 * — "not yok" tek bir hâl olmalı.
 *
 * SÜRÜM ÇARPIKLIĞI KAPISI GEREKMEZ (SyncPayload::gonderilenler'in konusu değil): order_lines satırı
 * LWW ile GÜNCELLENMEZ, olayla EKLENİR (`line_added`) ve silinir (`line_removed`). Notu bilmeyen
 * eski bir istemci var olan bir satırın notunu ezemez — çünkü var olan satıra hiç yazmaz.
 *
 * GERİYE DÖNÜK SENKRON YAYINI GEREKMEZ (migration 802'nin dersi burada tetiklenmiyor): hiçbir
 * satırın DEĞERİ değişmiyor, yalnız null bir sütun ekleniyor. İlk not yazıldığında normal push/pull
 * yolundan iner.
 *
 * RLS: order_lines Faz 2'den beri ENABLE+FORCE RLS (migration 000210); policy ve GRANT tablo
 * düzeyindedir, yeni sütun otomatik kapsanır (kolon düzeyinde yetki kullanılmıyor).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('order_lines', function (Blueprint $table) {
            $table->string('note', 500)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('order_lines', fn (Blueprint $t) => $t->dropColumn('note'));
    }
};
