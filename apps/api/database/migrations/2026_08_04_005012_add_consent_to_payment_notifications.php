<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * HUKUKİ ONAY KAYDI — `payment_notifications`a `consent_version` + `consented_at`.
 *
 * NEDEN VAR: bayi siteden "havale gönderdim" derken mesafeli satış sözleşmesini, ön bilgilendirme
 * formunu ve KVKK aydınlatmasını onaylar. Bu onayın HANGİ SÜRÜMÜ, NE ZAMAN kabul ettiği hukuki bir
 * kayıttır (BRIEF "yasal gereklilikler" maddesi) ve `subscription_payments`ta Faz 5b'den beri
 * BİRİNCİ SINIF kolonlarda duruyor. Beyan tarafında o kolonlar yoktu; site ajanı sürümleri
 * `note` alanına METİN olarak yazmak zorunda kalmıştı.
 *
 * NEDEN `note` YETMEZ: `note` bayinin/operatörün serbest metnidir — biçimi sözleşme değildir,
 * sorgulanamaz, ve bir uyuşmazlıkta "not alanında yazıyordu" savunma sayılmaz. Aynı bilgi iki
 * tabloda iki farklı biçimde durursa biri er geç bayatlar. Kolon tipleri `subscription_payments`
 * ile BİREBİR aynı seçildi (string nullable + timestampTz nullable) ki iki tablo arasında rapor
 * çıkarmak dönüşüm istemesin.
 *
 * CHECK — SÜRÜM VE DAMGA BİRLİKTE YOLCULUK EDER: `subscription_payments`ta bu eşleşme yalnız kod
 * disiplinine bağlı (`record()` içinde `consented_at = version !== null ? now() : null`). Burada
 * tablo YENİ ve hiç eski satırı yok, dolayısıyla kuralı DB'ye yazabiliyoruz: "sürüm var ama zaman
 * yok" satırı doğamaz. Zamansız bir onay kaydı, olmayan bir onaydan daha kötüdür — kayıt varmış
 * gibi görünür ama tarihi ispatlanamaz.
 *
 * KVKK: onayın SÜRÜMÜ ve ZAMANI yazılır; onay METNİ, IP, cihaz parmak izi YAZILMAZ.
 *
 * SENKRON: `payment_notifications` telefona İNMEZ (mobilde ödeme/abonelik yüzeyi yoktur — mağaza
 * kuralı). Geriye dönük yayın gerekmez; ayrıca hiçbir mevcut satırın DEĞERİ değişmiyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payment_notifications', function (Blueprint $table) {
            $table->string('consent_version')->nullable();
            $table->timestampTz('consented_at')->nullable();
        });

        DB::statement(
            'ALTER TABLE payment_notifications ADD CONSTRAINT payment_notifications_consent_check '.
            'CHECK ((consent_version IS NULL AND consented_at IS NULL) '.
            'OR (consent_version IS NOT NULL AND consented_at IS NOT NULL))'
        );
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE payment_notifications DROP CONSTRAINT IF EXISTS payment_notifications_consent_check');

        Schema::table('payment_notifications', function (Blueprint $table) {
            $table->dropColumn(['consent_version', 'consented_at']);
        });
    }
};
