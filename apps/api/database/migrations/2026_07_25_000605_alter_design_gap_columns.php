<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Tasarımın (Claude Design handoff v2, s-*.jsx) gerektirdiği ama mevcut şemada olmayan ALANLAR.
 * Hepsi ADDİTİF ve nullable/varsayılanlı — mevcut satırlar ve native arayan-tanıma sözleşmesi
 * (customers/customer_phones/phone_last10/balance_kurus) DOKUNULMAZ.
 *
 *  products.barcode      — s-urunler: barkod okutarak POS'a ekleme. Tekillik DB'de ZORLANMAZ:
 *                          iki cihaz çevrimdışıyken aynı barkodu girerse unique ihlali olayı
 *                          reddeder ve kullanıcının kaydı kaybolurdu (offline-first > katı bütünlük).
 *                          Mükerrer barkod yalnız okutmayı belirsizleştirir; UI uyarır. İndeks arama için.
 *  products.image_url    — s-urunler/POS karosu görseli. SUNUCUDA yalnız İŞARETÇİ tutulur (blob değil):
 *                          görsel yükleme (nesne deposu, TR yerleşim) ayrı bir iştir — AÇIK madde.
 *  customer_addresses.region — s-musteriler "Bölge" (Kepez/Muratpaşa/Lara); adres satırının yanında
 *                          gösterilir ve rota/bölge gruplaması için ayrı alan olmalı.
 *  orders.sort_index     — s-siparisler "Elle sırala (sürükle-bırak)" rota sırası. ÖNBELLEK sütunu;
 *                          kaynağı `sort_set` order_event'idir (status/assigned_user_id deseni),
 *                          böylece iki cihaz aynı sırayı deterministik türetir.
 *  order_lines.unit      — satır birimi ("2 adet × 45,00"). unit_price/product_name gibi SATIRDA
 *                          saklanır: siparişin çekildiği andaki gerçektir, ürünün bugünkü birimi değil.
 *  order_lines.is_custom — "serbest satır" (katalogda olmayan tek seferlik iş) ayırt edicisi. Tasarım
 *                          bunları AYRI gösteriyor; product_id IS NULL'a bel bağlamak kırılgandır
 *                          (silinmiş ürünün satırı da null olabilir) — açık bayrak sözleşmesi.
 *  users.updated_*       — kurye profili (ad/telefon/aktiflik) artık uygulamadan düzenlenebiliyor
 *                          (user_profile senkron olayı); LWW için meta gerekli.
 *  tenants.route_credits — s-siparisler "Oto Sırala (rota) · 34 hak". SUNUCU SAHİPLİ sayaç (istemci
 *                          yazamaz, abonelik gibi); subscription bloğuyla yayınlanır. Rota
 *                          optimizasyon servisinin kendisi ayrı bir iş — sayacın yeri hazır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->string('barcode', 32)->nullable();
            $table->text('image_url')->nullable();
            $table->index(['tenant_id', 'barcode']);
        });

        Schema::table('customer_addresses', function (Blueprint $table) {
            $table->string('region', 80)->nullable();
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->integer('sort_index')->nullable();
        });

        Schema::table('order_lines', function (Blueprint $table) {
            $table->string('unit', 20)->nullable();
            $table->boolean('is_custom')->default(false);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->timestampTz('updated_occurred_at')->nullable();
            $table->uuid('updated_device_id')->nullable();
        });

        Schema::table('tenants', function (Blueprint $table) {
            $table->integer('route_credits')->default(0);
        });

        // order_events.event_type CHECK'ini `sort_set` ile genişlet (Faz 4'te assigned/unassigned için
        // aynı DROP+ADD yapılmıştı — yoksa INSERT 23514 ile patlar).
        DB::statement('ALTER TABLE order_events DROP CONSTRAINT order_events_type_check');
        DB::statement(
            'ALTER TABLE order_events ADD CONSTRAINT order_events_type_check '.
            "CHECK (event_type IN ('created','line_added','line_removed','delivered','cancelled',".
            "'payment_set','note_set','assigned','unassigned','sort_set'))"
        );
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE order_events DROP CONSTRAINT order_events_type_check');
        DB::statement(
            'ALTER TABLE order_events ADD CONSTRAINT order_events_type_check '.
            "CHECK (event_type IN ('created','line_added','line_removed','delivered','cancelled',".
            "'payment_set','note_set','assigned','unassigned'))"
        );

        Schema::table('products', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'barcode']);
            $table->dropColumn(['barcode', 'image_url']);
        });
        Schema::table('customer_addresses', fn (Blueprint $t) => $t->dropColumn('region'));
        Schema::table('orders', fn (Blueprint $t) => $t->dropColumn('sort_index'));
        Schema::table('order_lines', fn (Blueprint $t) => $t->dropColumn(['unit', 'is_custom']));
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn(['updated_occurred_at', 'updated_device_id']));
        Schema::table('tenants', fn (Blueprint $t) => $t->dropColumn('route_credits'));
    }
};
