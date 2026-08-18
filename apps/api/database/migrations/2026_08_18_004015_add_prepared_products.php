<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * HAZIRLANAN ÜRÜN YETENEĞİ — tenant_settings.prepared_products (kullanıcı eleştirisi 2026-08-18).
 *
 * Ürün seçenekleri ("içinde şu olsun olmasın", migration 004014) ilk sürümde HER ürün formunda
 * koşulsuz görünüyordu. Kullanıcı haklı olarak itiraz etti: bu uygulamayı su bayii, tüp bayii,
 * market, dönerci, tostçu birlikte kullanıyor ve *"su bayisinde içindekiler göstermek çok
 * mantıklı değil"*. Bu kolon, özelliğin kiracı düzeyindeki anahtarıdır.
 *
 * ══ NEDEN BOOLEAN (YETENEK), NEDEN "business_type" METNİ DEĞİL ═════════════════════════════
 * Tek bir tür etiketi bu ürünü tarif EDEMEZ; kullanıcının kendi örneği bunu kanıtlıyor: "küçük
 * bir bakkal olabilir ama aynı zamanda tost yapıyor olabilir". Tür bir ETİKETTİR, davranışı
 * belirleyen şey YETENEKTİR. İleride gelecek kurulum sihirbazı türü soracak ve cevaptan bu
 * yeteneği TÜRETECEK; ekranlar yine yeteneği okuyacak. Ekranların doğrudan türü okuduğu bir
 * tasarım, bakkal-tost hâlinde kaçınılmaz olarak yanlış karar verirdi.
 *
 * ⚠️ VARSAYILAN false: sahadaki her bayi yükseltmeden sonra BUGÜNKÜ davranışı görür. Bu üründeki
 * bayilerin çoğunluğu su/tüp bayisidir (BRIEF); azınlığın ihtiyacını çoğunluğa dayatmak yanlış
 * yöndür. Kapalı olması VERİ SİLMEZ — `products.options` yerinde kalır, yalnız düzenleyici
 * gizlenir.
 *
 * SENKRON SÖZLEŞMESİ: yalnız EKLEME → MINOR. `ProfileChangeApplier` kolonu
 * `SyncPayload::gonderilenler` filtresinden geçirir, yani anahtarı BİLMEYEN eski bir istemcinin
 * profil yazımı bu değeri SİFİRLAMAZ (2026-08-05'te ödenmiş sürüm çarpıklığı dersi).
 *
 * RLS: tenant_settings ENABLE+FORCE RLS; policy ve GRANT tablo düzeyindedir, yeni sütun kapsanır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenant_settings', function (Blueprint $table) {
            $table->boolean('prepared_products')->default(false);
        });
    }

    public function down(): void
    {
        Schema::table('tenant_settings', fn (Blueprint $t) => $t->dropColumn('prepared_products'));
    }
};
