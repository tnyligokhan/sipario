<?php

namespace Tests\Feature\Api;

use App\Models\CashHandover;
use App\Models\DayClosing;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * AYNI KAPANIŞIN İKİ CİHAZDAN GELMESİ — sessiz yakınsama (lead kararı 2026-08-06, inceleme #①).
 *
 * ARIZA: patron kapanış sheet'ini açıkken kurye kendi telefonundan hesabını kapatırsa (ya da biri
 * çevrimdışıyken ikisi de kapatırsa) aynı kurye/gün için İKİ kapanış + İKİ devir yazılıyordu.
 * `teslimEdilenNakit` ikisini birden sayıyor, gün beklentisi 10.000 yerine 20.000 çıkıyor ve patron
 * kasasındaki 10.000'i sayınca "EKSİK 10.000" görüyordu — append-only olduğu için KALICI.
 *
 * ÇÖZÜM TEKİLLİK İNDEKSİ DEĞİL, TÜRETİLMİŞ ID'dir. Kapanış sunucuya İKİ AYRI OLAY olarak gider
 * (önce devir, sonra arşiv — AraTahsilatSyncTest o sırayı yazar) ve her olay kendi savepoint'indedir.
 * `day_closings`e unique indeks koymak devri COMMIT edip arşivi reddederdi: ortada SAHİPSİZ bir
 * devir kalır, o da "kapanışa bağlı olmayan devir" tanımı gereği ARA TAHSİLATA terfi eder ve çift
 * sayılan para hiç düzelmezdi. Kapak PARANIN DEFTERİNE (`cash_handovers`) konur.
 *
 * Bu dosyanın kilitlediği sözleşme:
 *  1. Aynı id ikinci kez gelince olay `duplicate` döner (istemcide `acked` → outbox temizlenir).
 *     `rejected` OLMAMALI: o istemcide KARANTİNAdır ve iyi huylu bir tekrarı elle incelemeye
 *     zorlardı — bu deponun çıktığı hata sınıfı tam olarak budur.
 *  2. Parti AKAR: aynı partideki diğer olaylar uygulanmaya devam eder.
 *  3. Satır TEK kalır ve İLK mutabakat korunur (ikinci sayım kayda geçmez — bilinçli bedel).
 *  4. Sahipsiz devir ÜRETİLMEZ, yani hayalet ara tahsilat doğmaz.
 *  5. Ara tahsilat serbestliği bozulmaz: FARKLI id'lerle gün içinde çok devir hâlâ yazılır.
 */
class KapanisYakinsamaTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /**
     * Üretimdeki kurye kapanışı: devir + ona bağlı arşiv, aynı partide, devir ÖNCE.
     * Id'ler dışarıdan verilir çünkü senaryonun tamamı "iki cihaz AYNI id'yi türetti"dir.
     *
     * @return list<array<string, mixed>>
     */
    private function kapanisPartisi(
        string $devirId,
        string $kapanisId,
        string $kuryeId,
        string $patronId,
        int $sayilan,
        string $device,
    ): array {
        $meta = ['occurred_at' => '2026-08-06T18:00:00Z', 'device_id' => $device]; // TR 21:00

        return [
            $this->cashHandover([
                'id' => $devirId,
                'from_user_id' => $kuryeId,
                'to_user_id' => $patronId,
                'counted_cash_kurus' => $sayilan,
                'expected_cash_kurus' => 10000,
                'diff_kurus' => $sayilan - 10000,
            ], $meta),
            $this->dayClosing([
                'id' => $kapanisId,
                'scope' => 'courier',
                'user_id' => $kuryeId,
                'cash_handover_id' => $devirId,
                'cash_nakit_kurus' => 10000,
                'expected_cash_kurus' => 10000,
                'counted_cash_kurus' => $sayilan,
                'diff_kurus' => $sayilan - 10000,
            ], $meta),
        ];
    }

    #[Test]
    public function ayni_kapanis_iki_cihazdan_gelince_sessizce_yakinsar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // İKİ CİHAZ AYNI ÇEKİRDEKTEN AYNI ID'LERİ TÜRETİR (uuid5(tenant|scope|user|TR gün)).
        // Test id'leri sabit veriyor: türetmenin KENDİSİ mobilin işi, sunucunun sözleşmesi
        // "aynı id = aynı mantıksal olay"dır ve burada sınanan o.
        $devirId = (string) Str::uuid7();
        $kapanisId = (string) Str::uuid7();

        // 1. cihaz: kurye kendi telefonundan kapatır, 100,00 ₺ sayar.
        $ilk = $this->pushEvents($token, $this->kapanisPartisi(
            $devirId, $kapanisId, $a['kurye']->id, $a['patron']->id, 10000, (string) Str::uuid7(),
        ));
        $ilk->assertOk();
        $ilk->assertJsonPath('results.0.status', 'applied');
        $ilk->assertJsonPath('results.1.status', 'applied');
        $seqIlkten = (int) $ilk->json('current_seq');

        // 2. cihaz: patron da aynı hesabı kapatır ve FARKLI bir tutar sayar (90,00 ₺). Ayrıca
        // partiye ALAKASIZ bir olay ekleniyor — "parti akıyor mu" ancak böyle kanıtlanır.
        $ikinciParti = $this->kapanisPartisi(
            $devirId, $kapanisId, $a['kurye']->id, $a['patron']->id, 9000, (string) Str::uuid7(),
        );
        $ikinciParti[] = $this->customerUpsert(['name' => 'Parti akmalı']);

        $ikinci = $this->pushEvents($token, $ikinciParti);
        $ikinci->assertOk();

        // (1) İkisi de DUPLICATE — `rejected` değil. Mobil beyaz listesi `duplicate`i `acked`
        //     sayar (sync_engine `_Karar.onayla`); `rejected` olsaydı satır karantinaya düşerdi.
        $ikinci->assertJsonPath('results.0.status', 'duplicate');
        $ikinci->assertJsonPath('results.1.status', 'duplicate');
        $this->assertSame($devirId, $ikinci->json('results.0.entity_id'));
        $this->assertSame($kapanisId, $ikinci->json('results.1.entity_id'));

        // (2) PARTİ AKTI: duplicate olaylar sonrasındaki olay uygulandı.
        $ikinci->assertJsonPath('results.2.status', 'applied');

        // (3) SATIR TEK ve İLK MUTABAKAT KORUNDU. İkinci cihazın 90,00'ı kayda GEÇMEZ — bedeli
        //     bilinçli: aynı gün iki kapanış yazmak düzeltilen para hatasının ta kendisiydi.
        $devirler = $this->asOwner(fn () => CashHandover::query()->get());
        $kapanislar = $this->asOwner(fn () => DayClosing::query()->get());
        $this->assertCount(1, $devirler, 'Aynı id ikinci devri YAZMAMALI.');
        $this->assertCount(1, $kapanislar, 'Aynı id ikinci kapanışı YAZMAMALI.');
        $this->assertSame(10000, (int) $devirler[0]->counted_cash_kurus,
            'İlk mutabakat kazanır; ikinci sayım kaydı EZMEZ.');
        $this->assertSame(10000, (int) $kapanislar[0]->counted_cash_kurus);

        // (4) SAHİPSİZ DEVİR YOK → hayalet ara tahsilat doğmadı. Tekillik indeksi seçilseydi
        //     buradan 1 çıkardı ve mobil onu "ara tahsilat" diye çizerdi.
        $bagliIdler = $this->asOwner(fn () => DayClosing::query()
            ->whereNotNull('cash_handover_id')->pluck('cash_handover_id')->all());
        $this->assertSame([], $devirler->whereNotIn('id', $bagliIdler)->pluck('id')->all(),
            'Kapanışa bağlanmamış devir kalmamalı — o, ara tahsilat sayılırdı.');

        // (5) Duplicate olay YENİ DEĞİŞİKLİK YAYMAZ: seq yalnız alakasız olay kadar ilerler,
        //     yani diğer cihazlar aynı kapanışı ikinci kez PULL etmez.
        $this->assertSame($seqIlkten + 1, (int) $ikinci->json('current_seq'),
            'Duplicate sync_changes üretmemeli; yoksa aynı kayıt tüm cihazlara tekrar inerdi.');
    }

    #[Test]
    public function ara_tahsilat_serbestligi_bozulmadi(): void
    {
        // Kısıt YALNIZ türetilmiş id'dedir. Ara tahsilatların id'si rastgele kalır, yani "gün
        // içinde çok kez kasa devri" akışı aynen çalışmalı — bu, ①'i düzeltirken kırılması en
        // kolay şeydi (cash_handovers'a (kurye, gün) unique koymak tam olarak bunu öldürürdü).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $device = (string) Str::uuid7();

        $olaylar = [];
        foreach ([50000, 30000, 12000] as $i => $tutar) {
            $olaylar[] = $this->cashHandover([
                'from_user_id' => $a['kurye']->id,
                'to_user_id' => $a['patron']->id,
                'counted_cash_kurus' => $tutar,
                'expected_cash_kurus' => $tutar,
                'diff_kurus' => 0,
            ], ['occurred_at' => sprintf('2026-08-06T%02d:00:00Z', 9 + $i * 4), 'device_id' => $device]);
        }

        $yanit = $this->pushEvents($token, $olaylar);
        $yanit->assertOk();
        foreach ([0, 1, 2] as $i) {
            $yanit->assertJsonPath("results.{$i}.status", 'applied');
        }

        $this->assertCount(3, $this->asOwner(fn () => CashHandover::query()->get()),
            'Aynı kurye + aynı gün ÜÇ ara tahsilat yan yana durmalı.');
    }

    #[Test]
    public function baska_kiracinin_ayni_idsi_duplicate_sayilmaz(): void
    {
        // KIRMIZI ÇİZGİ #1 KENARI. `day_closings.id` ve `cash_handovers.id` GLOBAL primary key'dir
        // (`unique(tenant_id,id)` bunun ÜSTÜNE ek kısıttır, PK'yı daraltmaz). Yani iki bayinin
        // kaydı teorik olarak aynı id'yi taşıyabilir — deterministik id çekirdeği bayi kodunu
        // unutursa `day|-|2026-08-06` TÜM bayilerde aynı uuid'yi üretirdi.
        //
        // TEHLİKE: `find($id) !== null` dalı 'duplicate' dönerse, B bayisinin kapanışı A'nın kaydı
        // yüzünden SESSİZCE yutulur ve istemci `acked` görüp satırı kuyruktan siler.
        //
        // ÖLÇÜLEN GERÇEK: bu olmuyor, çünkü `find()` RLS ALTINDA koşuyor. İki tabloda da
        // `tenant_isolation` politikası (cmd=ALL, yani SELECT dahil) + FORCE ROW LEVEL SECURITY
        // var; applier RLS'li `pgsql` bağlantısında ve `ResolveTenantContext` isteği tek
        // transaction'a sarıp `app.tenant_id`yi kuruyor. B'nin oturumunda A'nın satırı GÖRÜNMEZ →
        // `find()` null döner → INSERT denenir → GLOBAL PK ihlali (23505) → olay bazında
        // `rejected`. Yani sonuç 'duplicate' DEĞİL, GÖRÜNÜR bir reddir; istemci karantinaya alır.
        //
        // Bu test o zinciri UÇTAN UCA kilitler: zincirin herhangi bir halkası düşerse (politikadan
        // SELECT çıkarılır, applier owner bağlantısına taşınır, tenant bağlamı kurulmaz) burası
        // kırmızı yanar — ve o gün sessiz yutma gerçek olurdu.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $ortakId = (string) Str::uuid7();

        $kapanis = fn (array $seed) => $this->dayClosing([
            'id' => $ortakId,
            'scope' => 'day',
            'cash_nakit_kurus' => 10000,
            'expected_cash_kurus' => 10000,
            'counted_cash_kurus' => 10000,
        ], ['occurred_at' => '2026-08-06T18:00:00Z']);

        $this->pushEvents($this->tokenFor($a['patron']), [$kapanis($a)])
            ->assertOk()->assertJsonPath('results.0.status', 'applied');

        $bYanit = $this->pushEvents($this->tokenFor($b['patron']), [$kapanis($b)]);
        $bYanit->assertOk();

        $this->assertNotSame('duplicate', $bYanit->json('results.0.status'),
            'Başka kiracının id çakışması TEKRAR değildir; sessizce yutulamaz.');
        $bYanit->assertJsonPath('results.0.status', 'rejected');
        // MEKANİZMA DA ÇİVİLENİYOR, yalnız sonuç değil: `invalid_data` reddi bir QueryException'dan
        // (23505, global PK) gelir — yani `find()` GERÇEKTEN null döndü, A'nın satırını görmedi.
        // `domain_rejected` görseydik ret başka bir doğrulamadan gelirdi ve RLS'in daralttığı
        // iddiası kanıtlanmamış kalırdı.
        $bYanit->assertJsonPath('results.0.reason', 'invalid_data');

        // A'nın satırı DEĞİŞMEDİ ve B'ye hiçbir satır yazılmadı.
        $satirlar = $this->asOwner(fn () => DayClosing::query()->get());
        $this->assertCount(1, $satirlar, 'Çakışan olay ikinci satır yazmamalı.');
        $this->assertSame($a['tenant']->id, $satirlar[0]->tenant_id,
            'Kayıt A kiracısında kalmalı — B onu ne ezebilir ne devralabilir.');
        $this->assertSame(10000, (int) $satirlar[0]->counted_cash_kurus);

        // AYNI ZİNCİR PARANIN DEFTERİNDE DE GEÇERLİ olmalı — `cash_handovers` da global PK taşıyor
        // ve asıl para orada. İki uygulayıcının "yapısı aynı" varsayımıyla yetinmiyoruz.
        $devirId = (string) Str::uuid7();
        $devir = fn (array $seed) => $this->cashHandover([
            'id' => $devirId,
            'from_user_id' => $seed['kurye']->id,
            'counted_cash_kurus' => 9000,
            'expected_cash_kurus' => 9000,
            'diff_kurus' => 0,
        ], ['occurred_at' => '2026-08-06T18:00:00Z']);

        $this->pushEvents($this->tokenFor($a['patron']), [$devir($a)])
            ->assertOk()->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($this->tokenFor($b['patron']), [$devir($b)])
            ->assertOk()
            ->assertJsonPath('results.0.status', 'rejected')
            ->assertJsonPath('results.0.reason', 'invalid_data');

        $devirler = $this->asOwner(fn () => CashHandover::query()->get());
        $this->assertCount(1, $devirler);
        $this->assertSame($a['tenant']->id, $devirler[0]->tenant_id);
    }

    #[Test]
    public function ayni_olayin_retry_si_hala_duplicate_ve_tek_satir(): void
    {
        // Aynı cihazın ack'i kaybolup AYNI olayı (aynı client_event_id) yeniden göndermesi:
        // bu yol `processed_events` ile zaten kapalıydı, yeni dal onu BOZMAMALI.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $olay = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 7000,
            'expected_cash_kurus' => 7000,
            'diff_kurus' => 0,
        ], ['occurred_at' => '2026-08-06T18:00:00Z']);

        $this->pushEvents($token, [$olay])->assertOk()->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($token, [$olay])->assertOk()->assertJsonPath('results.0.status', 'duplicate');

        $this->assertCount(1, $this->asOwner(fn () => CashHandover::query()->get()));
    }
}
