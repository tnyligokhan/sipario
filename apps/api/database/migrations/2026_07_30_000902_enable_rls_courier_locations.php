<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * courier_locations kiracı izolasyonu (kırmızı çizgi #1). Faz 1/2/3/4 desenini birebir tekrarlar:
 * ENABLE + FORCE ROW LEVEL SECURITY + güvenli-varsayılan politika (app.tenant_id set edilmemişse
 * HİÇBİR satır görünmez) + açık GRANT.
 *
 * sipario_panel'e GRANT VERİLMEZ (bilinçli sapma — tasarım boşluğu migration'ı 606 panele SELECT
 * verir). Panel rolü BYPASSRLS'tir, yani ona verilen her SELECT bütün bayilerin verisini kiracı
 * ayrımı olmadan okuyabilmek demektir. Canlı koordinat, destek/faturalama panelinin işine yaramaz
 * ve KVKK açısından taşınabilecek en ağır alandır: panele HİÇ açılmaz. Yetkiyi vermemek, verip
 * "kullanmayız" demekten güçlüdür.
 *
 * DELETE app rolüne AÇIK bırakılır: kullanıcı konum paylaşımını kapattığında satırın SİLİNEBİLİR
 * olması gerekir (veri minimizasyonu bir kez yazdıktan sonra da geçerlidir).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
            ALTER TABLE courier_locations ENABLE ROW LEVEL SECURITY;
            ALTER TABLE courier_locations FORCE ROW LEVEL SECURITY;
            CREATE POLICY tenant_isolation ON courier_locations
                USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
                WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

            GRANT SELECT, INSERT, UPDATE, DELETE ON courier_locations TO sipario_app;
        SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
            DROP POLICY IF EXISTS tenant_isolation ON courier_locations;
            ALTER TABLE courier_locations NO FORCE ROW LEVEL SECURITY;
            ALTER TABLE courier_locations DISABLE ROW LEVEL SECURITY;
        SQL);
    }
};
