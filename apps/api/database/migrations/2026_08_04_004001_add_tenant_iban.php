<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * IBAN — tenant_settings.iban (kullanıcı isteği 2026-08-04).
 *
 * NEDEN VAR: borçlular ekranından tek tuşla WhatsApp hatırlatması gönderilecek ve mesajın içinde
 * bayinin IBAN'ı geçecek. IBAN bayi başına TEK bir değerdir ve işletme profilinin doğal parçasıdır
 * (unvan, telefon, vergi no ile aynı satır) — ayrı bir tablo, ayrı bir senkron varlığı ve ayrı bir
 * LWW damgası doğurmanın karşılığı yok.
 *
 * NEDEN 34 KARAKTER: IBAN standardının (ISO 13616) azami uzunluğu budur; TR IBAN'ı 26'dır. Ölçüyü
 * TR'ye kısmak, ileride yurt dışı hesabı olan bir bayide sessiz bir 22001 (value too long) üretirdi
 * ve o hata FORMDA değil senkron partisinde patlardı (panel test vardiyasının 22001 dersi).
 *
 * NEDEN DOĞRULAMA YOK (check constraint): IBAN'ın mod-97 denetimi istemcide yapılır ve kullanıcıya
 * ORADA söylenir. Veritabanı kısıtı aynı hatayı senkron partisinin içinde, bayinin anlamayacağı bir
 * yerde patlatırdı — üstelik bütün partiyi düşürerek. Sunucu tarafındaki tek kural uzunluktur.
 *
 * KVKK: IBAN bayinin KENDİ hesap bilgisidir, müşterinin değil — kiracı verisidir ve kiracı içinde
 * kalır. RLS tablo düzeyindedir, yeni sütun otomatik kapsanır.
 *
 * GERİYE DÖNÜK SENKRON YAYINI GEREKMEZ (migration 802'nin dersi burada tetiklenmiyor): hiçbir
 * satırın DEĞERİ değişmiyor, yalnız null bir sütun ekleniyor. Bayi IBAN'ını ilk yazdığında normal
 * push/pull yolundan inecek.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenant_settings', function (Blueprint $table) {
            $table->string('iban', 34)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('tenant_settings', fn (Blueprint $t) => $t->dropColumn('iban'));
    }
};
