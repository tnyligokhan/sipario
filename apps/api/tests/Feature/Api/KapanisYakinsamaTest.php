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
