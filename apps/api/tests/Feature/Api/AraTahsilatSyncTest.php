<?php

namespace Tests\Feature\Api;

use App\Models\CashHandover;
use App\Models\DayClosing;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * ARA TAHSİLAT — gün içinde ÇOK KEZ kasa devri (2026-08-06). Bugüne kadar sunucu tarafında yalnız
 * "gün sonunda tek devir" akışı sınanmıştı; mobilin gün özeti akışı öğlen/ikindi ara tahsilatları
 * yazıp günü kapanış devriyle bitiriyor.
 *
 * Bu dosya sunucunun o akışa ENGEL OLMADIĞINI kanıtlar ve engelsizliği KİLİTLER: ileride
 * cash_handovers'a "günde tek devir" benzeri bir unique/CHECK eklenirse buradaki testler kırmızı
 * yanar ve kararın bilinçli alınmasını zorlar.
 *
 * Sözleşmenin özeti: counted/expected/diff İSTEMCİ SNAPSHOT'ıdır — sunucu yeniden HESAPLAMAZ
 * (DECISIONS Faz 4). "Kalan nakit" tanımı tek yerde, mobilde yaşar; sunucu kanıtı append-only saklar.
 *
 * DAMGALAR BURADA UTC ('…Z') YAZILIR, mobilin `correctedNowIso`'su da öyle üretir. OFFSET'Lİ
 * ('+03:00') damga GÖNDERMEYİN: Eloquent'in datetime cast'i timestamptz kolonuna yazarken
 * `Y-m-d H:i:s` biçimlediği için offset DÜŞER ve Postgres yerel saati UTC sanar — kayıt 3 saat
 * ileri kayar (2026-08-06'da ölçüldü). Sessiz kalmasının tek sebebi mobilin UTC göndermesidir.
 */
class AraTahsilatSyncTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function ayni_kurye_ayni_gun_iki_ara_tahsilat_ve_gun_kapanisi(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $device = (string) Str::uuid7();

        // Öğlen: kurye kasadaki 500,00 ₺'yi patrona verir; sistem de 500,00 bekliyordu.
        $ara1 = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'to_user_id' => $a['patron']->id,
            'counted_cash_kurus' => 50000,
            'expected_cash_kurus' => 50000,
            'diff_kurus' => 0,
            'note' => 'ara tahsilat 1',
        ], ['occurred_at' => '2026-08-06T09:00:00Z', 'device_id' => $device]); // TR 12:00

        // İkindi: period_start ÖNCEKİ devrin anıdır — "şu andan beri toplanan" penceresi budur.
        // 10,00 ₺ eksik çıkar; fark kanıt olarak durur (BRIEF), ikinci devir birinciyi EZMEZ.
        $ara2 = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'to_user_id' => $a['patron']->id,
            'counted_cash_kurus' => 30000,
            'expected_cash_kurus' => 31000,
            'diff_kurus' => -1000,
            'period_start' => '2026-08-06T09:00:00Z',
            'note' => 'ara tahsilat 2',
        ], ['occurred_at' => '2026-08-06T13:00:00Z', 'device_id' => $device]); // TR 16:00

        // Gün sonu: kapanış devri + ona bağlı kapanış arşivi AYNI PARTİDE gider (üretimdeki akış).
        // Parti içi sıra önemlidir: day_closing, referans verdiği cash_handover'dan SONRA gelmeli.
        $kapanisDevri = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'to_user_id' => $a['patron']->id,
            'counted_cash_kurus' => 12000,
            'expected_cash_kurus' => 12000,
            'diff_kurus' => 0,
            'period_start' => '2026-08-06T13:00:00Z',
            'note' => 'gun sonu devri',
        ], ['occurred_at' => '2026-08-06T18:00:00Z', 'device_id' => $device]); // TR 21:00

        $kapanis = $this->dayClosing([
            'scope' => 'courier',
            'user_id' => $a['kurye']->id,
            'cash_handover_id' => $kapanisDevri['payload']['id'],
            'delivery_count' => 9,
            'total_collected_kurus' => 92000,
            'cash_nakit_kurus' => 92000,
            // Günün TAMAMI 920,00 toplandı ama 800,00'i ara tahsilatlarla zaten teslim edildi;
            // kapanışta beklenen yalnız KALAN 120,00'dir. Sunucu bu aritmetiği doğrulamaz —
            // aşağıda "verbatim saklanıyor mu" ayrı bir testle kanıtlanıyor.
            'expected_cash_kurus' => 12000,
            'counted_cash_kurus' => 12000,
            'diff_kurus' => 0,
        ], ['occurred_at' => '2026-08-06T18:00:00Z', 'device_id' => $device]);

        $yanit = $this->pushEvents($token, [$ara1, $ara2, $kapanisDevri, $kapanis]);
        $yanit->assertOk();
        foreach ([0, 1, 2, 3] as $i) {
            $yanit->assertJsonPath("results.{$i}.status", 'applied');
        }

        // Aynı kurye + aynı gün → ÜÇ devir yan yana durur. "Günde tek devir" diye bir kısıt YOK.
        $devirler = $this->asOwner(fn () => CashHandover::query()
            ->where('from_user_id', $a['kurye']->id)->orderBy('occurred_at')->get());
        $this->assertCount(3, $devirler, 'Gün içinde çok kez kasa devri kabul edilmeli.');
        $this->assertSame([50000, 30000, 12000], $devirler->pluck('counted_cash_kurus')->all());
        $this->assertSame([0, -1000, 0], $devirler->pluck('diff_kurus')->all());

        // Denetim izi: cihazsız/damgasız yazım bu depoda bilinen tuzaktır — her devir ikisini de taşır.
        foreach ($devirler as $devir) {
            $this->assertSame($device, $devir->device_id, 'Devir cihaz kimliği taşımalı.');
            $this->assertNotNull($devir->occurred_at, 'Devir olay damgası taşımalı.');
        }
        $this->assertSame(
            ['2026-08-06 09:00:00', '2026-08-06 13:00:00', '2026-08-06 18:00:00'],
            $devirler->map(fn ($d) => $d->occurred_at->utc()->format('Y-m-d H:i:s'))->all(),
            'Damgalar kaydırılmadan saklanmalı.'
        );
        $this->assertNull($devirler[0]->period_start, 'Günün ilk devrinde pencere başı yoktur.');
        $this->assertSame(
            '2026-08-06 09:00:00',
            $devirler[1]->period_start?->utc()->format('Y-m-d H:i:s'),
            'İkinci devrin penceresi ilk devrin anından başlamalı.'
        );

        // Kapanış arşivi, kendisine BAĞLI devri işaret eder; ara tahsilatlar bağsız kalır — sunucu
        // ikisini bu referansla ayırt eder (cash_handovers'ta "tür" alanı YOKTUR).
        $arsiv = $this->asOwner(fn () => DayClosing::query()->get());
        $this->assertCount(1, $arsiv);
        $this->assertSame($kapanisDevri['payload']['id'], $arsiv[0]->cash_handover_id);

        $bagliIdler = $this->asOwner(fn () => DayClosing::query()
            ->whereNotNull('cash_handover_id')->pluck('cash_handover_id')->all());
        $araTahsilatlar = $devirler->whereNotIn('id', $bagliIdler);
        $this->assertCount(2, $araTahsilatlar, 'Kapanışa bağlı olmayan devirler ara tahsilattır.');

        // Snapshot: mobil yeniden kurulduğunda üç devri de geri okur (append tablosu tam çekilir).
        $snap = $this->pullSince($token, 0);
        $this->assertCount(3, $snap->json('entities.cash_handover'));
        $this->assertCount(1, $snap->json('entities.day_closing'));
    }

    #[Test]
    public function sunucu_beklenen_nakdi_yeniden_hesaplamaz_istemci_snapshotunu_saklar(): void
    {
        // KRİTİK SÖZLEŞME: sunucu expected/counted/diff'i doğrulasaydı "kalan nakit" iki yerde
        // birden tanımlanır ve ara tahsilat akışında ıraksardı (sunucu ara tahsilatları düşmeyi
        // bilmiyor). Burada bilerek TUTARSIZ bir üçlü gönderiliyor: sunucu düzeltmeden saklamalı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $devir = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 7000,
            'expected_cash_kurus' => 9000,
            'diff_kurus' => 12345, // counted − expected DEĞİL: sunucu aritmetiğe karışmıyor
        ]);
        $this->pushEvents($token, [$devir])->assertJsonPath('results.0.status', 'applied');

        $row = $this->asOwner(fn () => CashHandover::query()->find($devir['payload']['id']));
        $this->assertNotNull($row);
        $this->assertSame(7000, $row->counted_cash_kurus);
        $this->assertSame(9000, $row->expected_cash_kurus);
        $this->assertSame(12345, $row->diff_kurus, 'İstemci snapshot\'ı verbatim saklanmalı.');
    }

    #[Test]
    public function gun_kapanisi_ozet_alanlari_da_verbatim_saklanir(): void
    {
        // Aynı sözleşme day_closings'in ÖZET alanları için de geçerli olmalı: istemci artık
        // kapanışta "kalan nakit" yazıyor (günün nakdi − ara tahsilatların SAYILAN toplamı).
        // Sunucu `expected_cash_kurus`'u kendi formülüyle (ör. nakit toplamı) yeniden hesaplasaydı
        // ilk ara tahsilatta ıraksardı. Aşağıdaki alanların HİÇBİRİ birbirini tutmuyor.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $kapanis = $this->dayClosing([
            'scope' => 'day',
            'delivery_count' => 9,
            'total_collected_kurus' => 92000,
            'cash_nakit_kurus' => 92000,
            'cash_kart_kurus' => 1,       // toplamla kasten tutarsız
            'cash_havale_kurus' => 2,
            'open_credit_kurus' => 55555,
            'expected_cash_kurus' => 12000, // "kalan nakit" — nakit toplamından KÜÇÜK
            'counted_cash_kurus' => 11000,
            'diff_kurus' => -1000,
        ]);
        $this->pushEvents($token, [$kapanis])->assertJsonPath('results.0.status', 'applied');

        $row = $this->asOwner(fn () => DayClosing::query()->find($kapanis['payload']['id']));
        $this->assertNotNull($row);
        $this->assertSame(9, $row->delivery_count);
        $this->assertSame(92000, $row->total_collected_kurus);
        $this->assertSame(1, $row->cash_kart_kurus);
        $this->assertSame(2, $row->cash_havale_kurus);
        $this->assertSame(55555, $row->open_credit_kurus);
        $this->assertSame(12000, $row->expected_cash_kurus, 'Kalan nakit sunucuda yeniden hesaplanmamalı.');
        $this->assertSame(11000, $row->counted_cash_kurus);
        $this->assertSame(-1000, $row->diff_kurus);
    }

    #[Test]
    public function ayni_gun_gun_kapanisi_ara_tahsilatlara_dokunmaz(): void
    {
        // Gün kapanışı bir ARŞİV yazımıdır; daha önce yazılmış ara tahsilat kayıtlarını ne siler
        // ne de günceller (append-only, migration 405 REVOKE ile DB seviyesinde de zorlanır).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $ara = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 40000,
            'expected_cash_kurus' => 40000,
            'diff_kurus' => 0,
        ]);
        $this->pushEvents($token, [$ara])->assertJsonPath('results.0.status', 'applied');
        $oncekiGuncelleme = $this->asOwner(
            fn () => CashHandover::query()->find($ara['payload']['id'])
        )->updated_at;

        // Kapanış, hiçbir devre BAĞLI OLMADAN da yazılabilir (cash_handover_id nullable):
        // patron gün sonunu kurye devri olmadan da kapatabilmeli.
        $this->pushEvents($token, [$this->dayClosing([
            'scope' => 'day',
            'total_collected_kurus' => 40000,
            'expected_cash_kurus' => 0,
        ])])->assertJsonPath('results.0.status', 'applied');

        $sonra = $this->asOwner(fn () => CashHandover::query()->find($ara['payload']['id']));
        $this->assertNotNull($sonra);
        $this->assertSame(40000, $sonra->counted_cash_kurus);
        $this->assertEquals($oncekiGuncelleme, $sonra->updated_at, 'Ara tahsilat satırı DEĞİŞMEMELİ.');
        $this->assertNull(
            $this->asOwner(fn () => DayClosing::query()->value('cash_handover_id')),
            'Devre bağlanmamış gün kapanışı da geçerlidir.'
        );
    }
}
