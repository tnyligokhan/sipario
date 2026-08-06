<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * IBAN ALICI ADI + BORÇ HATIRLATMA ŞABLONU — tenant_settings (kullanıcı isteği 2026-08-06).
 *
 * NEDEN `iban_owner_name`: hatırlatma mesajı IBAN'ın yanında "Alıcı:" satırı yazıyordu ve oraya
 * İŞLETME ADI konuyordu. Hesap sahibi çoğu zaman ŞAHIS adıdır ("Mehmet Yılmaz") ve banka
 * uygulaması havale ekranında ad soyad ister — müşteri işletme adını yazınca işlem geçmez.
 * Nullable: boş kaldığında istemci eskisi gibi işletme adına düşer, yani bu migration hiçbir
 * bayinin "Alıcı" satırını kaybettirmez. 120 hane, `users.name` sınırıyla aynı ölçü.
 *
 * NEDEN `reminder_template`: bayi mesajın cümlelerini kendisi kurabilmeli (ton, hitap, imza).
 * Nullable ve VARSAYILAN YAZILMAZ — null "bayi dokunmadı" demektir ve istemci varsayılan metni
 * kendi kodundan kurar. Varsayılanı satıra kopyalamak, metni ileride iyileştirdiğimizde şablona
 * hiç dokunmamış bayilerde eski metni dondururdu.
 *
 * NEDEN 1000 KARAKTER: WhatsApp'a giden tek bir hatırlatma metni için fazlasıyla geniş (varsayılan
 * ~200 karakter), ama sınırsız da değil — `text` kolonu, hatalı bir istemci ya da yapıştırılan bir
 * belge yüzünden senkron partisine megabaytlar taşıyabilirdi. Sınır UYGULAYICIDA da kontrol edilir
 * (ProfileChangeApplier): kolon sınırına dayanıp 22001 almak TÜM partiyi düşürürdü; oradan fırlayan
 * istisna savepoint ile yalnız BU olayı 'rejected' işaretler (IBAN'ın 34 hane kapısıyla aynı desen).
 *
 * DOĞRULAMA (yer tutucu denetimi) YOK — bilinçli: bilinmeyen `*...*` dizileri mesajda OLDUĞU GİBİ
 * kalır, çünkü WhatsApp'ta yıldız kalın yazı demektir ve bayinin kendi vurgusunu reddetmek
 * mesajını bozardı. Sunucudaki tek kural uzunluktur.
 *
 * KVKK: ikisi de bayinin KENDİ verisidir (hesap sahibi adı, kendi mesaj metni), müşterinin değil.
 * RLS tablo düzeyindedir, yeni sütunlar otomatik kapsanır.
 *
 * GERİYE DÖNÜK SENKRON YAYINI GEREKMEZ: hiçbir satırın DEĞERİ değişmiyor, yalnız null sütunlar
 * ekleniyor. Bayi ilk yazdığında normal push/pull yolundan iner.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenant_settings', function (Blueprint $table) {
            $table->string('iban_owner_name', 120)->nullable();
            $table->string('reminder_template', 1000)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('tenant_settings', fn (Blueprint $t) => $t->dropColumn([
            'iban_owner_name', 'reminder_template',
        ]));
    }
};
