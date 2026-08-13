<?php

namespace Tests\Feature\Api;

use App\Models\CashHandover;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * ARA TAHSİLAT İPTALİ (kullanıcı kararı 2026-08-13) — yönetici yanlış girilmiş bir ara tahsilatı
 * geri alabilir. GERÇEK SİLME YOKTUR (BRIEF kırmızı çizgi #2): iptal, `cash_handovers`a yazılan
 * TERS BİR SATIRdır — `counted_cash_kurus` negatif, expected/diff sıfır — ve `reverses_handover_id`
 * ile iptal ettiği kaydı gösterir (`ledger_entries.reverses_entry_id` deseninin aynısı).
 *
 * Bu dosya ÜÇ ŞEYİ kilitler ve üçü de para güvenliğidir:
 *   ① iptal uygulanır, kolon dolar ve `changes` ile DİĞER CİHAZA yayılır (yayılmayan iptal, o
 *      telefonda hiç olmamış demektir — "sunucuda doğru duran ama inmeyen alan YOKTUR");
 *   ② başka bayinin devrine iptal BAĞLANAMAZ (kırmızı çizgi #1);
 *   ③ aynı devir İKİ KEZ iptal edilemez — ne uygulayıcıdan (görünür red), ne veritabanından
 *      (eşzamanlı iki isteğin yarışı). Çift iptal, kasaya parayı İKİ KEZ geri döndürür ve tablo
 *      append-only olduğu için bir daha DÜZELMEZ.
 *
 * Damgalar UTC ('…Z') yazılır — gerekçesi için bkz. `AraTahsilatSyncTest` başlığı.
 */
class AraTahsilatIptalTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function ara_tahsilat_iptali_ters_satir_olarak_uygulanir_ve_changes_ile_yayilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $device = (string) Str::uuid7();

        // Öğlen ara tahsilatı: kurye 500,00 ₺ verdi.
        $ara = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'to_user_id' => $a['patron']->id,
            'counted_cash_kurus' => 50000,
            'expected_cash_kurus' => 50000,
            'diff_kurus' => 0,
            'note' => 'ara tahsilat',
        ], ['occurred_at' => '2026-08-13T09:00:00Z', 'device_id' => $device]);

        $this->pushEvents($token, [$ara])->assertJsonPath('results.0.status', 'applied');

        // Bu noktadan SONRAKİ değişiklikleri izleyeceğiz: iptalin gerçekten YAYILDIĞINI ancak
        // imleçten sonraki delta ile kanıtlayabiliriz (snapshot her şeyi zaten döndürürdü).
        $imlec = (int) $this->pullSince($token, 0)->json('cursor');

        // İptal: AYNI op ('handover'), yeni bir id, ters işaretli tutar + hedefi gösteren alan.
        $iptal = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'to_user_id' => $a['patron']->id,
            'counted_cash_kurus' => -50000,
            'expected_cash_kurus' => 0,
            'diff_kurus' => 0,
            'reverses_handover_id' => $ara['payload']['id'],
            'note' => 'yanlis girilmis, iptal',
        ], ['occurred_at' => '2026-08-13T10:00:00Z', 'device_id' => $device]);

        $this->pushEvents($token, [$iptal])->assertOk()->assertJsonPath('results.0.status', 'applied');

        // ① Sunucuda: İKİ satır yan yana durur. Orijinal kayıt SİLİNMEZ, DEĞİŞMEZ — kanıt kalır.
        $satirlar = $this->asOwner(fn () => CashHandover::query()->orderBy('occurred_at')->get());
        $this->assertCount(2, $satirlar, 'İptal, orijinali silmez — ters satır olarak eklenir.');
        $this->assertNull($satirlar[0]->reverses_handover_id, 'Orijinal devir bir iptal değildir.');
        $this->assertSame(50000, $satirlar[0]->counted_cash_kurus, 'Orijinal satır değişmemeli.');
        $this->assertSame($ara['payload']['id'], $satirlar[1]->reverses_handover_id);
        $this->assertSame(-50000, $satirlar[1]->counted_cash_kurus);

        // Kasa toplamı SUM ile türetilir; iptal kendiliğinden düşer — özel bir okuma dalı gerekmez.
        $this->assertSame(
            0,
            (int) $this->asOwner(fn () => CashHandover::query()->sum('counted_cash_kurus')),
            'Ters satır, iptal edilen tahsilatı toplamdan düşürmeli.'
        );

        // ② Delta: BAŞKA CİHAZ iptali görebilmeli ve yükte YENİ KOLON de gelmeli. Kolon `changes`
        // gövdesinde taşınmazsa iptal yalnız onu yazan telefonda var olur.
        $delta = $this->pullSince($token, $imlec);
        $delta->assertOk()->assertJsonPath('mode', 'delta');

        $devirDegisimleri = collect($delta->json('changes'))
            ->where('entity_type', 'cash_handover')->values();
        $this->assertCount(1, $devirDegisimleri, 'İptal tek bir cash_handover değişikliği yaymalı.');
        $this->assertSame($iptal['payload']['id'], $devirDegisimleri[0]['entity_id']);
        $this->assertSame(
            $ara['payload']['id'],
            $devirDegisimleri[0]['payload']['reverses_handover_id'],
            'reverses_handover_id senkron yükünde taşınmalı — yoksa iptal diğer cihaza HİÇ inmez.'
        );
        $this->assertSame(-50000, $devirDegisimleri[0]['payload']['counted_cash_kurus']);

        // Snapshot (yeni kurulum) yolu da aynı alanı taşımalı: iki yol AYRI kodtur (delta ham SQL,
        // snapshot Eloquent) ve birinde görünüp diğerinde kaybolan alan bu depoda bilinen tuzaktır.
        $snapshot = $this->pullSince($token, 0);
        $iptalSatiri = collect($snapshot->json('entities.cash_handover'))
            ->firstWhere('id', $iptal['payload']['id']);
        $this->assertNotNull($iptalSatiri);
        $this->assertSame($ara['payload']['id'], $iptalSatiri['reverses_handover_id']);
    }

    #[Test]
    public function iptal_alani_olmayan_normal_devir_bozulmaz(): void
    {
        // Geriye uyumluluk: alanı HİÇ göndermeyen (eski) istemcinin devri aynen uygulanır ve
        // kolon null kalır. Yeni alan opsiyoneldir — zorunlu olsaydı sürüm MAJOR olurdu ve
        // sahadaki telefonlar günlerce yazamazdı (CLAUDE.md "Sürümleme").
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $devir = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 12000,
            'expected_cash_kurus' => 12000,
            'diff_kurus' => 0,
        ]);
        $this->pushEvents($token, [$devir])->assertJsonPath('results.0.status', 'applied');

        $satir = $this->asOwner(fn () => CashHandover::query()->find($devir['payload']['id']));
        $this->assertNotNull($satir);
        $this->assertNull($satir->reverses_handover_id);
    }

    #[Test]
    public function baska_bayinin_devrine_iptal_baglanamaz(): void
    {
        // KIRMIZI ÇİZGİ #1. B bayisinin ara tahsilatı A bayisinden iptal EDİLEMEZ. Doğrulama RLS
        // kapsamında koştuğu için "yok" ile "başka bayinin" aynı kapıdan reddedilir — sızıntı
        // olmaması yetmez, sızıntının VARLIĞI bile (id tahmin ederek keşif) ölçülebilir olmamalı.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $bDevir = $this->cashHandover([
            'from_user_id' => $b['kurye']->id,
            'counted_cash_kurus' => 50000,
            'expected_cash_kurus' => 50000,
            'diff_kurus' => 0,
        ]);
        $this->pushEvents($this->tokenFor($b['patron']), [$bDevir])
            ->assertJsonPath('results.0.status', 'applied');

        $sahteIptal = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => -50000,
            'expected_cash_kurus' => 0,
            'diff_kurus' => 0,
            'reverses_handover_id' => $bDevir['payload']['id'],
        ]);

        $yanit = $this->pushEvents($this->tokenFor($a['patron']), [$sahteIptal]);
        $yanit->assertOk()
            ->assertJsonPath('results.0.status', 'rejected')
            ->assertJsonPath('results.0.reason', 'domain_rejected')
            ->assertJsonPath('results.0.message', 'reverses_handover_id bu bayide bulunamadı');

        // Ne A'da ters satır yazıldı, ne B'nin kaydına dokunuldu.
        $this->asOwner(function () use ($a, $b, $bDevir) {
            $this->assertSame(
                0,
                CashHandover::query()->where('tenant_id', $a['tenant']->id)->count(),
                'Reddedilen iptal hiçbir satır bırakmamalı (savepoint geri alır).'
            );
            $bSatir = CashHandover::query()->find($bDevir['payload']['id']);
            $this->assertNotNull($bSatir);
            $this->assertNull($bSatir->reverses_handover_id, 'B\'nin kaydı A tarafından işaretlenemez.');
            $this->assertSame($b['tenant']->id, $bSatir->tenant_id);
        });
    }

    #[Test]
    public function ayni_devir_iki_kez_iptal_edilemez(): void
    {
        // ÇİFT İPTAL = PARANIN İKİ KEZ GERİ GELMESİ. Bu tablo append-only olduğu için hata bir daha
        // düzelmez; yalnız üçüncü bir telafi kaydıyla örtülür — o da bayinin defteriyle tutmayan bir
        // kasa demektir. İstemcide de bir kapı var ama iki cihaz ÇEVRİMDIŞIYKEN aynı tahsilatı iptal
        // edebilir ve birbirlerini göremez; asıl kapak burasıdır.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $ara = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 50000,
            'expected_cash_kurus' => 50000,
            'diff_kurus' => 0,
        ]);
        $this->pushEvents($token, [$ara])->assertJsonPath('results.0.status', 'applied');

        $iptalKur = fn () => $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => -50000,
            'expected_cash_kurus' => 0,
            'diff_kurus' => 0,
            'reverses_handover_id' => $ara['payload']['id'],
        ]);

        $this->pushEvents($token, [$iptalKur()])->assertJsonPath('results.0.status', 'applied');

        // İkinci iptal FARKLI bir olaydır (yeni id, yeni client_event_id) — 'duplicate' değil
        // 'rejected' olmalı: sessizce yutulsaydı ikinci cihaz "iptal ettim" sanırdı.
        $ikinci = $this->pushEvents($token, [$iptalKur()]);
        $ikinci->assertOk()
            ->assertJsonPath('results.0.status', 'rejected')
            ->assertJsonPath('results.0.reason', 'domain_rejected')
            ->assertJsonPath('results.0.message', 'bu kasa devri zaten iptal edilmiş');

        $this->assertSame(
            1,
            $this->asOwner(fn () => CashHandover::query()
                ->where('reverses_handover_id', $ara['payload']['id'])->count()),
            'Bir devir en fazla BİR ters satır taşımalı.'
        );
        $this->assertSame(
            0,
            (int) $this->asOwner(fn () => CashHandover::query()->sum('counted_cash_kurus')),
            'Reddedilen ikinci iptal kasayı eksiye düşürmemeli.'
        );
    }

    #[Test]
    public function cift_iptal_veritabani_seviyesinde_de_imkansizdir(): void
    {
        // Uygulayıcıdaki kontrol OKU-SONRA-YAZ'dır: eşzamanlı iki isteğin İKİSİ de "henüz iptal yok"
        // görebilir ve ikisi de INSERT eder. O yarışı yalnız veritabanı kapatır (migration 004011,
        // kısmi unique indeks). Burada uygulama katmanı BİLEREK atlanıyor — testin konusu indeksin
        // VARLIĞI; indeks bir gün düşerse bu test kırmızı yanar, uygulayıcı testi ise yanmazdı.
        $a = $this->makeTenant('a');

        $this->asOwner(function () use ($a) {
            $hedef = (string) Str::uuid7();
            $satirlar = [
                ['id' => $hedef, 'ters' => null, 'tutar' => 50000],
                ['id' => (string) Str::uuid7(), 'ters' => $hedef, 'tutar' => -50000],
            ];
            foreach ($satirlar as $s) {
                $this->handoverEkle($a['tenant']->id, $s['id'], $s['ters'], $s['tutar']);
            }

            try {
                $this->handoverEkle($a['tenant']->id, (string) Str::uuid7(), $hedef, -50000);
                $this->fail('Aynı devri gösteren ikinci ters satır veritabanınca reddedilmeliydi.');
            } catch (QueryException $e) {
                $this->assertSame('23505', (string) $e->getCode(), 'Beklenen: unique ihlali.');
                // 23505 `SyncService::CLIENT_DATA_SQLSTATES` beyaz listesindedir; yarışı kaybeden
                // istek 500 değil 'rejected' alır ve PARTİNİN GERİ KALANI yazılmaya devam eder.
            }
        });
    }

    /** Uygulama katmanını atlayarak doğrudan satır ekler (yalnız DB kısıtlarını sınamak için). */
    private function handoverEkle(string $tenantId, string $id, ?string $tersId, int $tutar): void
    {
        DB::connection('pgsql_owner')->insert(
            'INSERT INTO cash_handovers
                (id, tenant_id, from_user_id, reverses_handover_id, counted_cash_kurus,
                 expected_cash_kurus, diff_kurus, occurred_at, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, 0, 0, now(), now(), now())',
            [$id, $tenantId, (string) Str::uuid7(), $tersId, $tutar]
        );
    }
}
