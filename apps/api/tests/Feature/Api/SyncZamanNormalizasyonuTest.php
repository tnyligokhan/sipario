<?php

namespace Tests\Feature\Api;

use App\Models\CashHandover;
use App\Models\Customer;
use App\Models\DayClosing;
use App\Models\LedgerEntry;
use App\Models\Order;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * SENKRON SINIRINDA ZAMAN NORMALİZASYONU (2026-08-06) — `SyncPayload::zaman()`.
 *
 * KORUNAN ŞEY: Eloquent'in datetime cast'i timestamptz kolonuna `Y-m-d H:i:s` yazdığı için
 * OFFSET DÜŞÜYORDU; '+03:00' ile gelen bir damga veritabanına yerel saatiyle girip UTC sanılıyor
 * ve 3 saat İLERİ kayıyordu. Türkiye +03:00 olduğundan bu kayma, gece geç saatte yazılan bir kasa
 * kaydını ERTESİ GÜNE düşürür — gün özeti/kapanış arşivi yanlış günü sayar ve arşiv append-only
 * olduğu için bir daha düzelmez.
 *
 * Bugün üretimde sessizdi: mobilin `correctedNowIso`'su 'Z' üretiyor. Bu dosya sözleşmeyi o
 * tesadüften kurtarır — üç yazım biçimi de aynı ana çözülmek ZORUNDA.
 */
class SyncZamanNormalizasyonuTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function uc_damga_bicimi_de_ayni_ana_cozulur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // Üçü de AYNI anı gösterir: 2026-08-06 09:00 UTC = TR 12:00.
        //  • 'Z'         → mobilin bugün ürettiği biçim
        //  • '+03:00'    → kaymaya yol açan biçim (panel/araç/ileride bir istemci)
        //  • offset'siz  → uygulama saat dilimi (UTC) varsayılır
        $bicimler = [
            '2026-08-06T09:00:00Z',
            '2026-08-06T12:00:00+03:00',
            '2026-08-06 09:00:00',
        ];

        $idler = [];
        foreach ($bicimler as $damga) {
            $devir = $this->cashHandover([
                'from_user_id' => $a['kurye']->id,
                'counted_cash_kurus' => 1000,
                'expected_cash_kurus' => 1000,
                'diff_kurus' => 0,
                'period_start' => $damga, // payload damgası da aynı kapıdan geçmeli
            ], ['occurred_at' => $damga]);
            $this->pushEvents($token, [$devir])->assertJsonPath('results.0.status', 'applied');
            $idler[] = $devir['payload']['id'];
        }

        foreach ($idler as $i => $id) {
            $row = $this->asOwner(fn () => CashHandover::query()->find($id));
            $this->assertNotNull($row);
            $this->assertSame(
                '2026-08-06 09:00:00',
                $row->occurred_at->utc()->format('Y-m-d H:i:s'),
                "'{$bicimler[$i]}' biçimi aynı ana çözülmeli (occurred_at)."
            );
            $this->assertSame(
                '2026-08-06 09:00:00',
                $row->period_start?->utc()->format('Y-m-d H:i:s'),
                "'{$bicimler[$i]}' biçimi aynı ana çözülmeli (period_start)."
            );
        }
    }

    #[Test]
    public function gec_saatte_offsetli_damga_tr_gun_sinirinin_dogru_tarafinda_kalir(): void
    {
        // ASIL KORUNAN SENARYO: bayi günü TR saatiyle 23:30'da kapatıyor. Doğru UTC karşılığı
        // 6 Ağustos 20:30. Offset düşürülseydi kayıt 6 Ağustos 23:30 UTC olur, TR'ye çevrilince
        // 7 AĞUSTOS 02:30'a düşerdi — kasa rakamı ertesi günün özetine yazılırdı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $devir = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 25000,
            'expected_cash_kurus' => 25000,
            'diff_kurus' => 0,
        ], ['occurred_at' => '2026-08-06T23:30:00+03:00']);

        $kapanis = $this->dayClosing([
            'scope' => 'courier',
            'user_id' => $a['kurye']->id,
            'cash_handover_id' => $devir['payload']['id'],
            'expected_cash_kurus' => 25000,
            'counted_cash_kurus' => 25000,
        ], ['occurred_at' => '2026-08-06T23:30:00+03:00']);

        $this->pushEvents($token, [$devir, $kapanis])->assertOk();

        $row = $this->asOwner(fn () => CashHandover::query()->find($devir['payload']['id']));
        $this->assertNotNull($row);
        $this->assertSame('2026-08-06 20:30:00', $row->occurred_at->utc()->format('Y-m-d H:i:s'));
        $this->assertSame(
            '2026-08-06',
            $row->occurred_at->setTimezone('Europe/Istanbul')->format('Y-m-d'),
            'Kasa kaydı TR takviminde 6 Ağustos günü kalmalı.'
        );

        $arsiv = $this->asOwner(fn () => DayClosing::query()->first());
        $this->assertNotNull($arsiv);
        $this->assertSame(
            '2026-08-06',
            $arsiv->occurred_at->setTimezone('Europe/Istanbul')->format('Y-m-d'),
            'Kapanış arşivi de aynı güne düşmeli.'
        );
    }

    #[Test]
    public function normalizasyon_diger_senkron_varliklarinda_da_gecerli(): void
    {
        // Düzeltme tek kapıda (SyncPayload::zaman) yapıldığı için tüm uygulayıcıları kapsamalı:
        // müşterinin LWW damgası, defter satırı ve sipariş de aynı anı görmeli.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $damga = '2026-08-06T12:00:00+03:00'; // = 09:00 UTC

        $musteri = $this->customerUpsert(['name' => 'Zaman Testi'], ['occurred_at' => $damga]);
        $this->pushEvents($token, [$musteri])->assertJsonPath('results.0.status', 'applied');

        $siparis = $this->orderCreated(
            [['id' => (string) Str::uuid7(), 'product_name' => 'Damacana',
                'unit_price_kurus' => 4500, 'qty' => 1, 'line_total_kurus' => 4500]],
            ['customer_id' => $musteri['payload']['id']],
            ['occurred_at' => $damga]
        );
        $this->pushEvents($token, [$siparis])->assertJsonPath('results.0.status', 'applied');

        $defter = $this->ledgerEntry([
            'customer_id' => $musteri['payload']['id'], 'entry_type' => 'debit', 'amount_kurus' => 4500,
        ], ['occurred_at' => $damga]);
        $this->pushEvents($token, [$defter])->assertJsonPath('results.0.status', 'applied');

        $beklenen = '2026-08-06 09:00:00';
        $musteriRow = $this->asOwner(fn () => Customer::query()->find($musteri['payload']['id']));
        $this->assertNotNull($musteriRow);
        $this->assertSame($beklenen, $musteriRow->updated_occurred_at->utc()->format('Y-m-d H:i:s'));

        $siparisRow = $this->asOwner(fn () => Order::query()->find($siparis['payload']['order']['id']));
        $this->assertNotNull($siparisRow);
        $this->assertSame($beklenen, $siparisRow->occurred_at->utc()->format('Y-m-d H:i:s'));

        $defterRow = $this->asOwner(fn () => LedgerEntry::query()->find($defter['payload']['id']));
        $this->assertNotNull($defterRow);
        $this->assertSame($beklenen, $defterRow->occurred_at->utc()->format('Y-m-d H:i:s'));
    }

    #[Test]
    public function damgasiz_alanin_davranisi_degismedi(): void
    {
        // Normalizasyon bir DOĞRULAMA KAPISI DEĞİLDİR: null yine null kalır, olay reddedilmez.
        // (Reddetme kapısı EventValidator'dır; burada olay düşürmek para kaydını yok etmek olurdu.)
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $devir = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 500,
            'expected_cash_kurus' => 500,
            'diff_kurus' => 0,
            // period_start HİÇ GÖNDERİLMİYOR — günün ilk devri
        ]);
        $this->pushEvents($token, [$devir])->assertJsonPath('results.0.status', 'applied');

        $row = $this->asOwner(fn () => CashHandover::query()->find($devir['payload']['id']));
        $this->assertNotNull($row);
        $this->assertNull($row->period_start, 'Damgasız alan null kalmalı.');
    }
}
