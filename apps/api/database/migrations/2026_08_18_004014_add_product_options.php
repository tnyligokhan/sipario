<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * ÜRÜN SEÇENEKLERİ — "içinde şu olsun / olmasın" (kullanıcı isteği 2026-08-18).
 *
 * Kullanıcının tarifi: "bir hızlı gıda işletmesi — gözlemeci, dönerci, dürümcü — müşteri içinde
 * şu olsun olmasın diyebilir. İşletmede her seferinde bunu sormak istemeyebilir."
 *
 * ÜÇ KOLON, ÜÇ FARKLI SORU:
 *   · products.options            → ürünün İÇİNDEKİLERİ + eklenebilir ekstralar (bayi tanımlar)
 *   · order_lines.options         → o satırda YAPILAN seçim ("soğansız")
 *   · customers.product_options   → o müşterinin SABİT tercihi (her seferinde sorulmasın)
 *
 * ══ NEDEN YENİ TABLO DEĞİL ═════════════════════════════════════════════════════════════════
 * `customers.favorite_product_ids` (migration 004010) ile BİREBİR aynı gerekçe ve orada yazılı:
 * yeni bir entity_type + tombstone + çakışma kuralı + pull dalı, bu bayi ölçeğinde taşınmayacak
 * bir maliyettir. Seçenek listesi tam olarak "bu ürünün bir alanı"dır; iki cihaz farklı liste
 * yazarsa çözüm LWW'nin kendisidir. İlişkisel sorgu ihtiyacı da YOK: veri yalnız GÖSTERİM ve
 * HATIRLAMA içindir, "hangi siparişlerde soğan çıkarıldı" diye bir rapor istenmiyor.
 *
 * ══ NEDEN `jsonb` DEĞİL `json` ═════════════════════════════════════════════════════════════
 * Alan bütün olarak yazılıp bütün olarak okunuyor; içinde arama yapılmıyor. `jsonb` yeniden
 * sıralama ve yeniden yazma maliyeti getirir, karşılığında burada kullanılmayan bir indeks
 * yeteneği verir. `json` ayrıca istemcinin yazdığı ANAHTAR SIRASINI korur — bayi malzemeleri
 * kendi düzenine göre sıralar ve o düzen listenin taşıdığı bilgidir.
 *
 * ══ SIRA MÜŞTERİNİN/BAYİNİN TERCİHİDİR ═════════════════════════════════════════════════════
 * `products.options` bir DİZİDİR ve sırası korunur (bayi en çok çıkarılanı başa alır).
 * `customers.product_options` bir NESNEDİR (ürün kimliği → seçim).
 *
 * SENKRON SÖZLEŞMESİ (SyncPayload kontrol listesi):
 *  · Yalnız EKLEME → eski istemci bilmediği anahtarı yok sayar; MINOR.
 *  · Hiçbir mevcut satırın DEĞERİ değişmiyor → geriye dönük `sync_changes` yayını gerekmez.
 *  · ⚠️ ESKİ İSTEMCİ İÇİN BEDEL: 0.28.0 ve öncesi bir telefon seçenekleri görmez ve satır
 *    notundaki özeti okur — yani "soğansız" bilgisi KAYBOLMAZ, çünkü uygulama onu `note`
 *    alanına da yazıyor. Bu, alanın metne de dökülmesinin asıl sebeplerinden biridir.
 *
 * ⚠️ SİLME TUZAĞI: `ChangeApplier`ın müşteri/ürün kolonları `SyncPayload::gonderilenler`
 * filtresinden geçer — anahtar payload'da HİÇ YOKSA mevcut değer korunur, AÇIKÇA null gelirse
 * temizlenir. Panelin ürün/müşteri formları bu anahtarları hiç göndermez, dolayısıyla bayinin
 * malzeme listesini panelden yapılan bir ad düzeltmesi silemez.
 *
 * RLS: üç tablo da ENABLE+FORCE RLS; policy ve GRANT tablo düzeyindedir, yeni sütun kapsanır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->json('options')->nullable();
        });
        Schema::table('order_lines', function (Blueprint $table) {
            $table->json('options')->nullable();
        });
        Schema::table('customers', function (Blueprint $table) {
            $table->json('product_options')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('products', fn (Blueprint $t) => $t->dropColumn('options'));
        Schema::table('order_lines', fn (Blueprint $t) => $t->dropColumn('options'));
        Schema::table('customers', fn (Blueprint $t) => $t->dropColumn('product_options'));
    }
};
