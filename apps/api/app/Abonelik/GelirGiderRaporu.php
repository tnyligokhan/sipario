<?php

namespace App\Abonelik;

use App\Models\Expense;
use Illuminate\Database\Eloquent\Collection;

/**
 * AYLIK GELİR–GİDER (tasarım `10-MasrafEkleModal.jsx` · `GelirGider` ekranı).
 *
 * GELİR = `subscription_payments` içindeki BAŞARILI satırların toplamı. Abonelik ödemesi de ek paket
 * geliri de aynı tablodadır (bkz. 005009) — bu yüzden rapor tek kaynaktan okunur ve "bir yeri
 * eklemeyi unutma" arızası yapısal olarak imkânsızdır. 'initiated'/'failed' satırları DIŞARIDA:
 * onlar girişimdir, para değil.
 *
 * AY SINIRI SABİT +03:00 (`Etc/GMT-3`, DST yok) — PanelStatsService ve DayEndRepository ile aynı.
 * `occurred_at` timestamptz'dir; UTC'ye göre gruplamak, gece 21:00'den sonra alınan her ödemeyi bir
 * sonraki aya yazardı ve ay sonu kapanışları sürekli birkaç kayıt kaydırırdı.
 *
 * `expenses.spent_on` DATE'tir → dönüşüm YOK. İki tarafın farklı tiplerde olması bilinçlidir: gelir
 * bir ANdır (ödemenin düştüğü an), gider bir GÜNdür (faturanın tarihi).
 *
 * Para her yerde İMZASIZ int KURUŞ; net NEGATİF olabilir (tek imzalı alan odur). Sunum katmanına
 * dönüşüm (₺, binlik ayraç) BURADA YAPILMAZ.
 */
class GelirGiderRaporu extends AbonelikServisi
{
    /**
     * Ay bazında özet, YENİDEN ESKİYE. Gelir veya gider görmüş HER ay listelenir (biri sıfır olsa
     * bile) — tasarımın soldaki "Aylık Özet" tablosu budur ve satır seçimi sağdaki kalem listesini
     * besler.
     *
     * @return list<array{ay: string, gelir_kurus: int, gider_kurus: int, net_kurus: int}>
     */
    public function aylikOzet(int $ayAdedi = 24): array
    {
        $gelir = [];
        foreach ($this->db()->table('subscription_payments')
            ->where('status', 'success')
            ->selectRaw("to_char(occurred_at AT TIME ZONE 'Etc/GMT-3', 'YYYY-MM') as ay, sum(amount_kurus) as toplam")
            ->groupBy('ay')->get() as $satir) {
            $gelir[(string) $satir->ay] = (int) $satir->toplam;
        }

        $gider = [];
        foreach ($this->db()->table('expenses')
            ->selectRaw("to_char(spent_on, 'YYYY-MM') as ay, sum(amount_kurus) as toplam")
            ->groupBy('ay')->get() as $satir) {
            $gider[(string) $satir->ay] = (int) $satir->toplam;
        }

        $aylar = array_unique(array_merge(array_keys($gelir), array_keys($gider)));
        rsort($aylar);
        $aylar = array_slice($aylar, 0, $ayAdedi);

        $sonuc = [];
        foreach ($aylar as $ay) {
            $g = $gelir[$ay] ?? 0;
            $m = $gider[$ay] ?? 0;
            $sonuc[] = ['ay' => $ay, 'gelir_kurus' => $g, 'gider_kurus' => $m, 'net_kurus' => $g - $m];
        }

        return $sonuc;
    }

    /**
     * Seçili ayın masraf kalemleri (sağdaki kart).
     *
     * @return Collection<int, Expense>
     */
    public function ayKalemleri(string $ay): Collection
    {
        return (new MasrafServisi($this->connection))->ay($ay);
    }

    /**
     * Tek ayın özeti — panel gösterge paneli "bu ay" kutusu için tam tarama yapmadan.
     *
     * @return array{ay: string, gelir_kurus: int, gider_kurus: int, net_kurus: int}
     */
    public function ay(string $ay): array
    {
        $gelir = (int) $this->db()->table('subscription_payments')
            ->where('status', 'success')
            ->whereRaw("to_char(occurred_at AT TIME ZONE 'Etc/GMT-3', 'YYYY-MM') = ?", [$ay])
            ->sum('amount_kurus');

        $gider = (int) $this->db()->table('expenses')
            ->whereRaw("to_char(spent_on, 'YYYY-MM') = ?", [$ay])
            ->sum('amount_kurus');

        return ['ay' => $ay, 'gelir_kurus' => $gelir, 'gider_kurus' => $gider, 'net_kurus' => $gelir - $gider];
    }
}
