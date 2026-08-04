<?php

namespace Tests\Unit;

use App\Livewire\Panel\Concerns\Bicim;
use Illuminate\Support\Carbon;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

/**
 * PARA GİRDİSİNİN ÇÖZÜMÜ — panelin para ekranlarındaki TEK dönüşüm noktası.
 *
 * Buradaki her satır sahadan bir yazım alışkanlığıdır. Esnaf "1.250,50" yazar, birisi "1250.50"
 * yazar, birisi kopyala-yapıştırla "₺ 1.250,50" bırakır. Yanlış çözülen bir tutar, bir bayinin
 * aboneliğine yanlış para yazar ve bu append-only bir tabloda düzeltilemez.
 */
class PanelBicimTest extends TestCase
{
    /** @return list<array{0: string, 1: int|null}> */
    public static function tutarlar(): array
    {
        return [
            ['1250', 125000],
            ['1250,50', 125050],
            ['1.250,50', 125050],       // TR yazımı: nokta binlik, virgül ondalık
            ['1250.50', 125050],        // klavye alışkanlığı: nokta ondalık (2 hane)
            ['1,250.50', 125050],       // İngiliz yazımı: son ayraç ondalıktır
            ['1.250', 125000],          // tek nokta + TAM 3 hane → binlik
            ['1.250.000', 125000000],   // çok nokta → hepsi binlik
            ['45,5', 4550],
            ['0,05', 5],
            ['₺ 1.250,50', 125050],     // birim ve boşluk temizlenir
            ['0', 0],
            ['', null],
            ['abc', null],
            ['12,34,56', null],         // birden çok virgül belirsiz → REDDEDİLİR (0 varsayılmaz)
            ['1,', null],
        ];
    }

    #[Test]
    #[DataProvider('tutarlar')]
    public function lira_metni_kurusa_cevrilir(string $ham, ?int $beklenen): void
    {
        $this->assertSame($beklenen, Bicim::kurus($ham));
    }

    #[Test]
    public function kurus_ile_lira_gidip_gelir(): void
    {
        foreach ([0, 5, 4550, 59900, 598800, 125050] as $kurus) {
            $this->assertSame($kurus, Bicim::kurus(Bicim::lira($kurus)));
        }
    }

    #[Test]
    public function sunum_bicimi_binlik_ayracli_ve_son_ekli(): void
    {
        $this->assertSame('1.250,50 ₺', Bicim::tl(125050));
        $this->assertSame('0,00 ₺', Bicim::tl(0));
        $this->assertSame('+1.250,50 ₺', Bicim::tlNet(125050));
        $this->assertSame('−850,00 ₺', Bicim::tlNet(-85000));
    }

    #[Test]
    public function ay_ve_tarih_etiketleri_turkcedir(): void
    {
        $this->assertSame('Ağustos 2026', Bicim::ayAdi('2026-08'));
        $this->assertSame('Ağu', Bicim::ayKisa('2026-08'));
        $this->assertSame('4 Ağu 2026', Bicim::tarihKisa(Carbon::parse('2026-08-04', 'UTC')));
        $this->assertSame('—', Bicim::tarihKisa(null));
        $this->assertSame('—', Bicim::tarihSaat(null));
        $this->assertSame('—', Bicim::tarihSaat(''));
    }

    #[Test]
    public function tarih_saat_sabit_03_00_duvar_saatiyle_basilir(): void
    {
        // config('app.timezone') UTC'dir; ekran ise deponun her yerindeki gün sınırıyla (+03:00)
        // aynı duvar saatini göstermeli — yoksa liste ile aylık özet farklı gün/ay söyler.
        $this->assertSame('4 Ağu 2026 14:30', Bicim::tarihSaat(Carbon::parse('2026-08-04 11:30', 'UTC')));

        // GECE YARISI SINIRI: UTC'de 4 Ağustos 22:00, TR'de 5 Ağustos 01:00'dir. Dönüştürmeseydik
        // liste "4 Ağu" derken aylık özet bu satırı 5 Ağustos'a yazardı.
        $this->assertSame('5 Ağu 2026 01:00', Bicim::tarihSaat(Carbon::parse('2026-08-04 22:00', 'UTC')));
        $this->assertSame('5 Ağu 2026', Bicim::tarihKisa(Carbon::parse('2026-08-04 22:00', 'UTC')));

        // Saat İKİ HANE sıfır dolgulu (tablo hizası).
        $this->assertSame('4 Ağu 2026 03:05', Bicim::tarihSaat(Carbon::parse('2026-08-04 00:05', 'UTC')));
    }

    #[Test]
    public function tarih_uzun_tam_ay_ve_gun_adi_verir(): void
    {
        // Tasarımın pano başlığı: "4 Ağustos 2026 Salı".
        $this->assertSame('4 Ağustos 2026 Salı', Bicim::tarihUzun(Carbon::parse('2026-08-04', 'UTC')));
        $this->assertSame('—', Bicim::tarihUzun(null));

        // GUNLER pazartesiden başlar; Carbon'un pazardan başlayan dayOfWeek'i ile karıştırılırsa
        // her gün bir kayar. Bir haftanın yedisi de sırayla doğrulanıyor.
        $beklenen = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
        foreach ($beklenen as $i => $gunAdi) {
            // 3 Ağustos 2026 pazartesidir.
            $gun = Carbon::parse('2026-08-03', 'UTC')->addDays($i);
            $this->assertStringEndsWith($gunAdi, Bicim::tarihUzun($gun));
        }
    }

    #[Test]
    public function bugun_ekranin_gununu_verir_utcnin_degil(): void
    {
        $bugun = Bicim::bugun();

        $this->assertSame('+03:00', $bugun->format('P'), 'Sabit +03:00 olmalı (DST taşımaz).');

        // UTC gece yarısından sonraki üç saatte gün AYRIŞIR; pano bu yüzden bugun()'u kullanmalı.
        $this->assertSame(
            Carbon::now('UTC')->addHours(3)->toDateString(),
            $bugun->toDateString(),
        );
    }

    #[Test]
    public function date_kolonlari_gun_kaydirmaz(): void
    {
        // spent_on / granted_on / declared_on DATE'tir; Eloquent onları UTC 00:00 kurar.
        // +3 saat ileri almak 03:00 yapar ve GÜN DEĞİŞMEZ — dönüşüm bu alanlara zararsızdır.
        foreach (['2026-01-01', '2026-08-04', '2026-12-31'] as $iso) {
            $this->assertSame(
                Bicim::tarihKisa(Carbon::parse($iso, 'UTC')),
                Bicim::tarihKisa(Carbon::parse($iso.' 00:00:00', 'UTC')),
            );
        }

        $this->assertSame('1 Oca 2026', Bicim::tarihKisa(Carbon::parse('2026-01-01', 'UTC')));
        $this->assertSame('31 Ara 2026', Bicim::tarihKisa(Carbon::parse('2026-12-31', 'UTC')));
    }

    #[Test]
    public function bicimleme_cagirana_ait_carbonu_degistirmez(): void
    {
        // setTimezone nesneyi yerinde değiştirir; kopyalamasaydık aynı istekte modelin alanı
        // sessizce kayar ve başka bir hesap bozulurdu.
        $t = Carbon::parse('2026-08-04 22:00', 'UTC');
        Bicim::tarihSaat($t);

        $this->assertSame('UTC', $t->timezoneName);
        $this->assertSame('2026-08-04 22:00', $t->format('Y-m-d H:i'));
    }

    #[Test]
    public function donem_secenekleri_bugune_gore_kayar_ve_yil_sinirini_asar(): void
    {
        // Ocak başında bir önceki yılın Aralık'ı seçilebilmeli — sabit yıl listesi bunu yapamazdı.
        $secenekler = Bicim::donemSecenekleri(Carbon::create(2027, 1, 15));

        $this->assertCount(12, $secenekler);
        $this->assertArrayHasKey('2026-11', $secenekler);
        $this->assertArrayHasKey('2026-12', $secenekler);
        $this->assertArrayHasKey('2027-01', $secenekler);
        $this->assertSame('Aralık 2026', $secenekler['2026-12']);
    }
}
