<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * OTO-SIRALAMA HAKKININ AYLIK YENİLENMESİ (kullanıcı kararı 2026-09-26: "Oto Sıralama hakkı her
 * ay yenilenmeli! Her ay ücretsiz bir şekilde belli bir hak veriyor olmamız gerekiyordu zaten!
 * Eğer ay içerisinde bitirirse satın alabilir.")
 *
 * Kullanım koşulları ve site bunu zaten VAAT EDİYORDU ("aylık kontör her ayın başında yenilenir
 * ve devretmez"; ek paket "süresi dolmaz, sonraki aya devreder") ama hiçbir kod yenilemiyordu.
 *
 * ══ NEDEN İKİ YENİ KOLON ══════════════════════════════════════════════════════════════════
 * `route_credits` KALAN TOPLAM hak olarak kalır (mobil sözleşmesi değişmez). Ama yenilemede
 * ücretsiz kısım SIFIRLANIR, satın alınan kısım KORUNUR — tek sayaçla ikisi ayırt edilemez:
 *  • `route_credits_purchased` — kalan toplamın SATIN ALINMIŞ kısmı. Harcamada önce ücretsiz hak
 *    düşer; bu sayı ancak kalan toplam onun altına inerse azalır. Değişmez: 0 ≤ purchased ≤ total.
 *  • `route_credits_renewed_on` — son yenilemenin DÖNEM BAŞI (ayın 1'i). Yenileme bu tarihe
 *    bakarak idempotenttir: aynı ay ikinci kez çalışan iş hiçbir şey yapmaz.
 *
 * ══ MEVCUT BAYİLER ═════════════════════════════════════════════════════════════════════════
 * Kontör paketi almış bayinin BÜTÜN kalanı satın alınmış sayılır — ayrım bilinmiyor ve yanlış
 * tarafa düşmek bayinin parasını silmek olurdu; cömert taraf seçildi. `renewed_on` NULL
 * bırakılır: ilk yenileme turu (zamanlanmış iş ya da ilk istek) ödeyen bayilere bu ayın
 * ücretsiz hakkını hemen verir.
 *
 * Migration owner (sipario_owner) ile koşar: `artisan migrate --database=pgsql_owner --force`.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $t) {
            $t->integer('route_credits_purchased')->default(0);
            $t->date('route_credits_renewed_on')->nullable();
        });

        DB::statement(
            'ALTER TABLE tenants ADD CONSTRAINT tenants_route_credits_purchased_check '.
            'CHECK (route_credits_purchased >= 0)'
        );

        DB::statement(
            'UPDATE tenants SET route_credits_purchased = GREATEST(route_credits, 0) '.
            "WHERE EXISTS (SELECT 1 FROM addon_grants g WHERE g.tenant_id = tenants.id AND g.type = 'credits')"
        );
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_route_credits_purchased_check');
        Schema::table('tenants', function (Blueprint $t) {
            $t->dropColumn(['route_credits_purchased', 'route_credits_renewed_on']);
        });
    }
};
