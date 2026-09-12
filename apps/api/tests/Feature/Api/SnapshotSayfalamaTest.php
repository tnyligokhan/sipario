<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\CustomerPhone;
use App\Models\Product;
use App\Support\Provisioning;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * İLK SENKRONUN SAYFALANMASI (2026-09-12) — saha arızasının gerileme bekçisi.
 *
 * YAŞANAN: 9.047 müşterili bir bayide tek parça snapshot 15,3 MB tutuyordu ve telefonun 25
 * saniyelik zaman aşımına sığmıyordu; bayinin telefonunda ürünler ve müşterilerin çoğu HİÇ
 * görünmedi. Sayfalama bu yüzden var.
 *
 * BURADA SINANAN ASIL ŞEY BOYUT DEĞİL, BÜTÜNLÜKTÜR: sayfalara bölmek hiçbir satırı ATLAMAMALI
 * ve hiçbirini TEKRARLAMAMALI. Bir sayfalayıcının sessizce satır düşürmesi, düzeltmeye
 * çalıştığımız arızanın ta kendisidir.
 */
class SnapshotSayfalamaTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /** @return array{0: array<string, mixed>, 1: string} tenant + patron token */
    private function bayi(): array
    {
        $a = $this->makeTenant('a');

        return [$a, $this->tokenFor($a['patron'])];
    }

    /** Tek bir snapshot sayfası çeker. */
    private function sayfa(string $token, string $imlec, int $limit = 50): array
    {
        return $this->asToken($token)
            ->getJson('/api/v1/sync/pull?since=0&sayfali=1&limit='.$limit.'&snapshot_cursor='.urlencode($imlec))
            ->assertOk()
            ->json();
    }

    /**
     * Sayfaları sonuna kadar gezip tip başına kimlikleri toplar.
     *
     * @return array{0: array<string, list<string>>,1: int} [tip → id listesi, sayfa sayısı]
     */
    private function tumSayfalar(string $token, int $limit = 50): array
    {
        $toplanan = [];
        $imlec = '';
        $sayfa = 0;

        do {
            $cevap = $this->sayfa($token, $imlec, $limit);
            $this->assertSame('snapshot', $cevap['mode']);
            foreach ($cevap['entities'] as $tip => $satirlar) {
                foreach ($satirlar as $satir) {
                    $toplanan[$tip][] = (string) ($satir['id'] ?? $satir['tenant_id']);
                }
            }
            $imlec = (string) ($cevap['snapshot_cursor'] ?? '');
            $sayfa++;
            $this->assertLessThan(200, $sayfa, 'Sayfalar ilerlemiyor — sonsuz döngü riski.');
        } while ($cevap['has_more']);

        return [$toplanan, $sayfa];
    }

    private function musteriUret(string $tenantId, int $adet): void
    {
        Provisioning::asOwner(function () use ($tenantId, $adet) {
            for ($i = 0; $i < $adet; $i++) {
                $id = (string) Str::uuid7();
                Customer::on('pgsql_owner')->create([
                    'id' => $id, 'tenant_id' => $tenantId, 'name' => 'Müşteri '.$i,
                    'updated_occurred_at' => now(),
                ]);
                CustomerPhone::on('pgsql_owner')->create([
                    'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId, 'customer_id' => $id,
                    'phone_e164' => '+9053200000'.str_pad((string) $i, 2, '0', STR_PAD_LEFT),
                    'phone_last10' => '53200000'.str_pad((string) $i, 2, '0', STR_PAD_LEFT),
                    'updated_occurred_at' => now(),
                ]);
            }
        });
    }

    #[Test]
    public function sayfali_snapshot_hicbir_satiri_atlamaz_ve_tekrarlamaz(): void
    {
        [$a, $token] = $this->bayi();
        $this->musteriUret($a['tenant']->id, 40);

        [$toplanan, $sayfaSayisi] = $this->tumSayfalar($token, limit: 7);

        $this->assertGreaterThan(1, $sayfaSayisi, 'Küçük limitle snapshot gerçekten bölünmeliydi.');
        $this->assertCount(40, $toplanan['customer'] ?? [], 'Müşterilerin TAMAMI gelmeli.');
        $this->assertCount(40, $toplanan['customer_phone'] ?? [], 'Telefonların TAMAMI gelmeli.');

        foreach ($toplanan as $tip => $idler) {
            $this->assertSame(count($idler), count(array_unique($idler)),
                "$tip tipinde TEKRAR eden satır var — sayfalama imleci kayıyor.");
        }
    }

    #[Test]
    public function sayfali_ve_sayfasiz_snapshot_ayni_kumeyi_dondurur(): void
    {
        // İKİ YOLUN AYRIŞMASI SESSİZ BİR ARIZADIR: eski istemci bir veri, yeni istemci başka bir
        // veri indirirse bunu kimse fark etmez. Varlık listesi tek yerde tutulmalı.
        [$a, $token] = $this->bayi();
        $this->musteriUret($a['tenant']->id, 12);

        $tekParca = $this->asToken($token)->getJson('/api/v1/sync/pull?since=0&limit=500')
            ->assertOk()->json();
        [$sayfali] = $this->tumSayfalar($token, limit: 5);

        foreach ($tekParca['entities'] as $tip => $satirlar) {
            if ($satirlar === []) {
                continue;
            }
            $beklenen = array_map(fn ($s) => (string) ($s['id'] ?? $s['tenant_id']), $satirlar);
            sort($beklenen);
            $gelen = $sayfali[$tip] ?? [];
            sort($gelen);
            $this->assertSame($beklenen, $gelen, "$tip tipi iki yolda FARKLI geldi.");
        }
    }

    #[Test]
    public function imlecsiz_istek_eski_davranisi_korur(): void
    {
        // SAHADAKİ 1.2.0/1.3.0 TELEFONLARI: `snapshot_cursor` göndermezler ve tek parça snapshot
        // beklerler. Sayfalamayı koşulsuz açmak onları kırardı — ilk sayfada imleci sona
        // damgalayıp geri kalanı bir daha hiç istemezlerdi.
        [$a, $token] = $this->bayi();
        $this->musteriUret($a['tenant']->id, 30);

        $cevap = $this->asToken($token)->getJson('/api/v1/sync/pull?since=0&limit=5')
            ->assertOk()->json();

        $this->assertSame('snapshot', $cevap['mode']);
        $this->assertFalse($cevap['has_more'], 'İmleçsiz snapshot TEK PARÇA olmalı.');
        $this->assertCount(30, $cevap['entities']['customer'],
            'limit imleçsiz snapshot`u kırpmamalı — eski istemci kalanı hiç istemez.');
    }

    #[Test]
    public function bos_bayide_sayfali_snapshot_tek_turda_biter(): void
    {
        [, $token] = $this->bayi();

        $cevap = $this->sayfa($token, '');

        $this->assertFalse($cevap['has_more']);
        $this->assertNull($cevap['snapshot_cursor']);
        // tenant_settings tek satırdır ve boş bayide de gelir; müşteri gelmemeli.
        $this->assertArrayNotHasKey('customer', $cevap['entities']);
    }

    #[Test]
    public function bozuk_imlec_bastan_baslatir_500_vermez(): void
    {
        // İmleci üreten de tüketen de biziz, ama varlık listesi bir gün değişirse sahadaki
        // yarım kalmış bir senkron 500 ALMAMALI: baştan başlamak yavaştır, kırılmaktan iyidir.
        [$a, $token] = $this->bayi();
        $this->musteriUret($a['tenant']->id, 3);

        foreach (['olmayan_tip:123', 'bozuk', ''] as $imlec) {
            $cevap = $this->sayfa($token, $imlec);
            $this->assertSame('snapshot', $cevap['mode'], "imleç '$imlec' 500 vermemeli");
            $this->assertCount(3, $cevap['entities']['customer'] ?? [],
                "imleç '$imlec' baştan başlatmalı");
        }
    }

    #[Test]
    public function cursor_alani_kiracinin_guncel_seqini_tasir(): void
    {
        // İstemci snapshot BİTTİĞİNDE bu değeri `lastPulledSeq` olarak damgalar; her sayfada
        // aynı olmalı, yoksa son sayfanın damgası ilk sayfadan eski kalır ve aradaki
        // değişiklikler BİR DAHA gelmez.
        [$a, $token] = $this->bayi();
        $this->musteriUret($a['tenant']->id, 20);

        $ilk = $this->sayfa($token, '', 5);
        $ikinci = $this->sayfa($token, (string) $ilk['snapshot_cursor'], 5);

        $this->assertSame($ilk['cursor'], $ikinci['cursor']);
        $this->assertSame($ilk['current_seq'], $ikinci['current_seq']);
    }

    #[Test]
    public function urunler_de_sayfali_snapshotta_gelir(): void
    {
        // SAHA ŞİKÂYETİNİN İKİNCİ YARISI: "panelde 6 ürün var, uygulamada 1 tane".
        [$a, $token] = $this->bayi();
        Provisioning::asOwner(function () use ($a) {
            foreach (['Tombul Tüp', 'Gri Şişman Tüp', 'Uzun Tüp', 'Madran Su'] as $ad) {
                Product::on('pgsql_owner')->create([
                    'id' => (string) Str::uuid7(), 'tenant_id' => $a['tenant']->id,
                    'name' => $ad, 'unit_price_kurus' => 0, 'updated_occurred_at' => now(),
                ]);
            }
        });
        $this->musteriUret($a['tenant']->id, 25);

        [$toplanan] = $this->tumSayfalar($token, limit: 6);

        $this->assertCount(4, $toplanan['product'] ?? [],
            'Ürünler müşterilerin ARDINDAN gelir; sayfalama onları düşürmemeli.');
    }
}
