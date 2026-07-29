<?php

use App\Models\Customer;
use App\Models\Order;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * GERİYE DÖNÜK ATANAN KODLARI SENKRONA DÜŞÜR.
 *
 * SAHA HATASI (2026-07-29, aynı gün bulundu): bir önceki migration mevcut müşteri ve
 * siparişlere kod atadı — ama düz SQL ile, `sync_changes` kaydı ÜRETMEDEN. İstemci ilk
 * snapshot'tan sonra YALNIZ delta çeker (`SyncService::pull`, since > 0), dolayısıyla o
 * kodlar telefona ASLA ulaşmazdı. Ölçüldü: sunucuda 11 kodlu müşteri, `sync_changes` içinde
 * kod taşıyan kayıt sayısı SIFIR.
 *
 * Arıza tipi tanıdık ve bu depoda pahalıya mal oldu: hiçbir şey çökmez, hiçbir günlük satırı
 * düşmez — yalnız hiçbir şey olmaz. Bayi "kodları göremiyorum" der, sunucuya bakan geliştirici
 * kodların orada durduğunu görür ve sorunu istemcide arar.
 *
 * DERS (DECISIONS'a yazıldı): **veriyi değiştiren her migration, o veriyi senkrona da
 * düşürmek zorundadır.** Sunucudaki doğru değer, istemciye ULAŞMIYORSA yoktur.
 *
 * NEDEN SNAPSHOT'A ZORLAMIYORUZ: istemciye "imleci sıfırla" diyecek bir kanal yok; olsaydı bile
 * tüm defteri yeniden indirmek (yıllara yayılan sipariş/defter satırları) bir kolon için
 * ölçüsüz olurdu. Delta üretmek hem küçük hem de mevcut yolun aynısı.
 */
return new class extends Migration
{
    public function up(): void
    {
        /** @var list<string> $tenantIds */
        $tenantIds = DB::table('tenants')->pluck('id')->all();

        foreach ($tenantIds as $tenantId) {
            // Push yolunun yaptığının aynısı: satır yoksa 0'dan başlat.
            DB::insert(
                'INSERT INTO tenant_sync_state (tenant_id, last_seq) VALUES (?, 0) ON CONFLICT (tenant_id) DO NOTHING',
                [$tenantId]
            );
            $seq = (int) (DB::table('tenant_sync_state')->where('tenant_id', $tenantId)->value('last_seq') ?? 0);
            $simdi = now()->toIso8601String();

            foreach ([['customer', Customer::class], ['order', Order::class]] as [$tip, $sinif]) {
                // Silinmiş kayıt ATLANIR: tombstone istemciye zaten gitti, kodu artık ilgisiz.
                // `code IS NOT NULL` süzgeci, ileride kodsuz kalabilecek satırları da korur.
                $sinif::query()
                    ->where('tenant_id', $tenantId)
                    ->whereNull('deleted_at')
                    ->whereNotNull('code')
                    ->orderBy('code')
                    ->chunkById(500, function ($satirlar) use (&$seq, $tenantId, $tip, $simdi) {
                        foreach ($satirlar as $m) {
                            $seq++;
                            DB::insert(
                                'INSERT INTO sync_changes
                                    (tenant_id, seq, entity_type, entity_id, op, payload, occurred_at)
                                 VALUES (?, ?, ?, ?, ?, ?, ?)',
                                [
                                    $tenantId, $seq, $tip, $m->id, 'upsert',
                                    // Payload SyncPayload::change ile AYNI şekilde üretilir
                                    // (model attributesToArray) — istemci iki farklı biçimle
                                    // karşılaşmamalı, yoksa tarih alanları LWW'de ayrışır.
                                    json_encode($m->attributesToArray(), JSON_UNESCAPED_UNICODE),
                                    $simdi,
                                ]
                            );
                        }
                    });
            }

            DB::update('UPDATE tenant_sync_state SET last_seq = ?, updated_at = now() WHERE tenant_id = ?',
                [$seq, $tenantId]);
        }
    }

    public function down(): void
    {
        // Geri alma YOK: sync_changes append-only bir günlüktür ve istemciler bu satırları
        // çoktan tüketmiş olabilir. Silmek, imleci ileride olan bir cihazı geri döndürmez —
        // yalnız günlüğü delik bırakır.
    }
};
