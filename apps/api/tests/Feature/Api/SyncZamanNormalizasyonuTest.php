<?php

namespace Tests\Feature\Api;

use App\Models\CashHandover;
use App\Models\Customer;
use App\Models\DayClosing;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\TenantSetting;
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
    public function isletme_profili_damgasi_da_normalize_edilir(): void
    {
        // `tenant_settings` ayrı bir uygulayıcıdan (ProfileChangeApplier) geçer; normalizasyon
        // orada eksik kalsaydı depoda İKİ zaman yorumu olurdu — profilin LWW damgası kayar,
        // ayarları kimin kazandığı sessizce değişirdi.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $ayar = $this->tenantSettingsUpsert(
            ['business_name' => 'Zaman Su Bayii'],
            ['occurred_at' => '2026-08-06T12:00:00+03:00']
        );
        $this->pushEvents($token, [$ayar])->assertJsonPath('results.0.status', 'applied');

        $row = $this->asOwner(fn () => TenantSetting::query()->find($a['tenant']->id));
        $this->assertNotNull($row);
        $this->assertSame('2026-08-06 09:00:00', $row->updated_occurred_at->utc()->format('Y-m-d H:i:s'));
    }

    #[Test]
    public function ayni_saniye_icinde_daha_eski_yazim_yeniyi_ezemez(): void
    {
        // AÇIK BORÇ — bu test BİLEREK "incomplete" bırakıldı (2026-08-06). Kapatılması ŞEMA
        // değişikliği gerektiriyor, uygulama katmanında çözülemiyor.
        //
        // LWW damgası saniye-altını TAŞIYAMIYOR ve kırpma İKİ KATMANDA birden oluyor:
        //  1. Eloquent'in varsayılan `$dateFormat`'ı `Y-m-d H:i:s` — mikrosaniyeyi düşürüyor.
        //  2. DAHA BASKINI: kolonların hepsi `timestamptz(0)` (ölçüldü — `information_schema`
        //     `datetime_precision = 0`, 18 kolonun tamamında). Postgres saniyeye YUVARLIYOR;
        //     yani cast kaldırılıp ham dize yazılsa bile saniye-altı veritabanına HİÇ girmiyor.
        //
        // Sonuç: aynı saniyeye düşen iki yazımda `lwwWins` damgada beraberliğe düşüp `device_id`
        // karşılaştırmasına iniyor. Ayrım DETERMİNİSTİKTİR (DECISIONS: "eşitlikte device_id ile
        // deterministik ayrım") ama SEMANTİK DEĞİLDİR: kazanan, daha yeni olan değil, kimliği
        // büyük olandır — yani çevrimdışı bir cihazın daha eski yazımı daha yenisini ezebilir.
        //
        // Bu taviz depoda zaten biliniyor ve panel tarafında BİLİNÇLİ olarak aşılıyor:
        // `PanelSyncYazici::damga()` sentetik bir PANEL_DEVICE_ID + "kendi damgasını bir saniye
        // ileri alma" hilesi kullanıyor (aynı hile `Livewire\Site\Ekip`te de var). Mobil senkron
        // yolunda böyle bir kapak YOK.
        //
        // Kapatma yolu: `ALTER COLUMN ... TYPE timestamptz(6)` — 18 kolon, üretim verisi ve
        // "değer değiştiren migration `sync_changes`e delta düşürmeli" kuralı (SyncPayload şema
        // evrimi sözleşmesi). Geniş yarıçaplı; vardiya sonu işi değil.
        //
        // Düzeltme geldiğinde tek yapılacak şey aşağıdaki satırı silmektir; testin gövdesi zaten
        // doğru kazananı bekliyor.
        $this->markTestIncomplete(
            'LWW saniye-altı ayrımı yok: kolonlar timestamptz(0), kapatmak migration ister.'
        );

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $musteriId = (string) Str::uuid7();
        $cihazA = (string) Str::uuid7();
        $cihazB = (string) Str::uuid7();

        // Cihaz A saniyenin GEÇ anında (09:00:00.900) yeni adı yazar.
        $yeni = $this->customerUpsert(
            ['id' => $musteriId, 'name' => 'Yeni Ad'],
            ['occurred_at' => '2026-08-06T09:00:00.900000Z', 'device_id' => $cihazA]
        );
        $this->pushEvents($token, [$yeni])->assertJsonPath('results.0.status', 'applied');

        // Cihaz B çevrimdışıyken saniyenin ERKEN anında (09:00:00.100) yazmıştı; şimdi senkronluyor.
        $eski = $this->customerUpsert(
            ['id' => $musteriId, 'name' => 'Eski Ad'],
            ['occurred_at' => '2026-08-06T09:00:00.100000Z', 'device_id' => $cihazB]
        );
        $this->pushEvents($token, [$eski])->assertJsonPath('results.0.status', 'stale');

        $row = $this->asOwner(fn () => Customer::query()->find($musteriId));
        $this->assertNotNull($row);
        $this->assertSame('Yeni Ad', $row->name, 'Daha eski yazım yeniyi ezmemeli.');
        $this->assertSame(
            '2026-08-06 09:00:00.900000',
            $row->updated_occurred_at->utc()->format('Y-m-d H:i:s.u'),
            'Mikrosaniye saklanmalı — kırpılırsa LWW aynı saniye içinde ayrım yapamaz.'
        );
    }

    #[Test]
    public function goreli_damgali_olay_partiyi_dusurmez(): void
    {
        // ZEHİRLİ HAP KAPISI: `EventValidator` damgayı `Carbon::parse` ile doğrular, Postgres daha
        // katıdır. Ölçüldü — `'next monday'` Carbon'da çözülür ama `timestamptz`'e yazılırken 22007
        // verir. Normalizasyondan önce bu ham dize `sync_changes` INSERT'üne gidiyor, 22007 beyaz
        // listede olmadığı için TÜM PARTİ 500'e düşüyordu: istemci hiçbir olayı işaretleyemez,
        // aynı partiyi sonsuza dek yeniden yollar, kuyruk kalıcı kilitlenirdi.
        //
        // Artık damga sınırda UTC'ye çözülüyor; olay uygulanıyor ve partinin geri kalanı AKIYOR.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $once = $this->customerUpsert(['name' => 'Once Gelen']);
        $goreli = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 100,
            'expected_cash_kurus' => 100,
            'diff_kurus' => 0,
        ], ['occurred_at' => 'next monday']);
        $sonra = $this->customerUpsert(['name' => 'Sonra Gelen']);

        $yanit = $this->pushEvents($token, [$once, $goreli, $sonra]);
        $yanit->assertOk();
        $yanit->assertJsonPath('results.0.status', 'applied');
        $yanit->assertJsonPath('results.1.status', 'applied');
        // Üçüncü olayın da uygulanmış olması partinin göreli damgadan sonra AKTIĞINI gösterir.
        $yanit->assertJsonPath('results.2.status', 'applied');

        // Kuyruk gerçekten ilerledi mi: partinin üç olayı da yazıldı.
        $this->assertSame(2, $this->asOwner(fn () => Customer::query()->count()));
        $this->assertSame(1, $this->asOwner(fn () => CashHandover::query()->count()));
    }

    #[Test]
    public function bozuk_payload_damgasi_yalniz_o_olayi_reddeder(): void
    {
        // `period_start` bir PAYLOAD alanıdır; `EventValidator`'ın damga kapısından GEÇMEZ.
        // Çözülemeyen değer `zaman()`ten olduğu gibi çıkar (doğrulama kapısı değildir) ve
        // Carbon'un `InvalidFormatException`'ı — ki `InvalidArgumentException` alt sınıfıdır —
        // SyncService tarafından per-olay yakalanır. Parti düşmemeli.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $bozuk = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 100,
            'expected_cash_kurus' => 100,
            'diff_kurus' => 0,
            'period_start' => 'abc',
        ]);
        $saglam = $this->customerUpsert(['name' => 'Saglam Kayit']);

        $yanit = $this->pushEvents($token, [$bozuk, $saglam]);
        $yanit->assertOk();
        // İkinci olayın uygulanması, bozuk damganın partiyi rehin ALMADIĞINI gösterir.
        $yanit->assertJsonPath('results.1.status', 'applied');

        $this->assertSame(1, $this->asOwner(fn () => Customer::query()->count()));
        $this->assertSame(0, $this->asOwner(fn () => CashHandover::query()->count()),
            'Bozuk damgalı devir yazılmamalı.');
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
