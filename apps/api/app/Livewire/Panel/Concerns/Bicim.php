<?php

namespace App\Livewire\Panel\Concerns;

use Illuminate\Support\Carbon;

/**
 * PARA EKRANLARININ SUNUM/GİRDİ ÇEVİRİLERİ — tek yerde.
 *
 * Para sistemde her yerde İMZASIZ int KURUŞtur (DECISIONS); `₺`, binlik ayraç ve virgül YALNIZ
 * burada doğar ve YALNIZ burada çözülür. Dört ekranın (Ödemeler · Paketler · Gelir-Gider ·
 * Bildirimler) hepsi bu sınıftan geçer: iki ekranın aynı tutarı farklı biçimde göstermesi bu
 * depoda daha önce yaşandı ve kaynağı, çevirinin ekran ekran kopyalanmasıydı.
 *
 * AY ADLARI da burada: `Ağustos 2026` etiketi hem ödeme süzgecinde hem gelir-gider tablosunda
 * geçer. Tasarımın AYLAR dizisi (`03-BUGUN.jsx`) birebir taşındı; PHP'nin yerelleştirilmiş ay
 * adları KULLANILMADI çünkü `APP_LOCALE=en` ve yerel ayarın bir gün değişmesi ekran metnini
 * sessizce İngilizceye çevirirdi.
 *
 * GÜN/AY SINIRI BURADA HESAPLANMAZ. 'YYYY-MM' anahtarını üreten tek yer sunucudur
 * (GelirGiderRaporu / OdemeKayitServisi, sabit +03:00); bu sınıf yalnız ETİKET üretir. Ama bir
 * ZAMAN DAMGASINI ekrana basarken hangi duvar saatiyle basacağını seçmek zorundadır ve o seçim
 * sunucununkiyle AYNI olmalıdır — bkz. GUN_DILIMI.
 */
final class Bicim
{
    /** Tasarımın AYLAR dizisi — sıra ve yazım ekrandakiyle aynıdır. */
    public const AYLAR = [
        'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];

    /**
     * Gün adları, PAZARTESİDEN başlar (ISO-8601). `AYLAR` ile aynı gerekçe: `->locale('tr')`
     * bir çağrı yerinde unutulduğu gün o ekran "Tuesday" der. Dizin `dayOfWeekIso - 1`dir
     * (1=Pazartesi … 7=Pazar); Carbon'un `dayOfWeek`i pazardan başladığı için o KULLANILMADI.
     */
    public const GUNLER = [
        'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
    ];

    /**
     * SUNUM SAAT DİLİMİ — sabit +03:00, deponun her yerindeki gün/ay sınırıyla AYNI
     * (GelirGiderRaporu · PanelStatsService · DayEndRepository · PanelCsvExportService · Dashboard).
     * `Etc/GMT-3` POSIX işaretiyle UTC+3 demektir ve DST taşımaz.
     *
     * NEDEN GEREKLİ: `config('app.timezone')` UTC'dir. Bir `timestamptz`i olduğu gibi basmak, onu
     * UTC duvar saatiyle göstermek demektir — oysa aynı satır raporlarda İSTANBUL gününe göre
     * gruplanır. Gece 23:30'da (TR) alınan bir ödeme listede "20:30" ve BİR ÖNCEKİ GÜN görünürken
     * aylık özette doğru aya düşerdi: tam olarak "iki ekran farklı sayı gösteriyor" arızası.
     *
     * DATE kolonlarına (spent_on, granted_on, declared_on) zararsızdır: Eloquent onları UTC 00:00
     * olarak kurar, +3 saat ileri almak 03:00 yapar ve GÜN DEĞİŞMEZ.
     */
    private const GUN_DILIMI = 'Etc/GMT-3';

    /**
     * Form tavanı: 100.000.000,00 ₺ (10 milyar kuruş).
     *
     * Para kolonları `bigint`tir (≈9,2×10^18) — yani bu tavan taşma koruması DEĞİL, yazım hatası
     * korumasıdır. `int4` varsaymak bu depoda bir kez pahalıya patladı; tavanı örneğe göre değil
     * kolon tipine göre seçiyoruz ve bigint'in çok altında, insan eliyle girilebilecek en büyük
     * makul rakamda duruyoruz.
     */
    public const TAVAN_KURUS = 10_000_000_000;

    /** '2026-08' → 'Ağustos 2026'. Tanınmayan anahtar olduğu gibi döner (ekran çökmez). */
    public static function ayAdi(string $anahtar): string
    {
        [$yil, $ay] = array_pad(explode('-', $anahtar), 2, '');
        $i = (int) $ay - 1;

        return isset(self::AYLAR[$i]) ? self::AYLAR[$i].' '.$yil : $anahtar;
    }

    /** '2026-08' → 'Ağu' (grafik ekseni). */
    public static function ayKisa(string $anahtar): string
    {
        [, $ay] = array_pad(explode('-', $anahtar), 2, '');
        $i = (int) $ay - 1;

        return isset(self::AYLAR[$i]) ? mb_substr(self::AYLAR[$i], 0, 3) : $anahtar;
    }

    /** Tasarımın `tarihK` biçimi: '3 Ağu 2026'. */
    public static function tarihKisa(Carbon|string|null $tarih): string
    {
        $c = self::gun($tarih);

        return $c === null
            ? '—'
            : $c->day.' '.mb_substr(self::AYLAR[$c->month - 1], 0, 3).' '.$c->year;
    }

    /**
     * Tarih + saat: '4 Ağu 2026 14:30'. Panelin zaman damgası taşıyan her listesi bunu kullanır
     * (defter · siparişler · denetim · cihazlar · hesaplar · denetim günlüğü).
     *
     * `->locale('tr')->isoFormat('D MMM YYYY HH:mm')` YERİNE: çıktı bugün birebir aynı ama o yol
     * ay adlarını YEREL AYARDAN alır. `APP_LOCALE` bugün 'en'; 'tr' yalnız çağrı yerinde elle
     * veriliyor ve bir yerde unutulduğu gün o ekran "4 Aug 2026" der. Ay adları bu sınıfta
     * sabittir, yerel ayar değişse de ekran değişmez.
     *
     * Saat İKİ HANE sıfır dolgulu ve 24 saat (`H:i`) — 'ss' biçiminde bir gece yarısı "0:05"
     * hizalaması tabloda bozar.
     */
    public static function tarihSaat(Carbon|string|null $tarih): string
    {
        $c = self::gun($tarih);

        return $c === null ? '—' : self::tarihKisa($c).' '.$c->format('H:i');
    }

    /**
     * Tam tarih + gün adı: '4 Ağustos 2026 Salı' (tasarımın pano başlığı). `tarihKisa()` kısa ay
     * verir; pano başlığı tam ay ister, bu yüzden ayrı yardımcı.
     */
    public static function tarihUzun(Carbon|string|null $tarih): string
    {
        $c = self::gun($tarih);

        return $c === null
            ? '—'
            : $c->day.' '.self::AYLAR[$c->month - 1].' '.$c->year.' '.self::GUNLER[$c->dayOfWeekIso - 1];
    }

    /**
     * "Bugün" — SUNUCUNUN gününde değil, EKRANIN gününde (+03:00).
     *
     * `now()` `config('app.timezone')`i, yani UTC'yi verir. Panonun başlığı onunla yazıldığında
     * TR saatiyle gece 00:00–03:00 arasında BİR ÖNCEKİ GÜN görünür — "bugün kime bakmalıyım"
     * panosunun yanlış günü yazması küçük ama tam bu sınıftan bir arıza. Gün sınırı sorulacak
     * her yerde bu metot kullanılır; çağıranın saat dilimi ADINI bilmesine gerek yoktur
     * (GUN_DILIMI bilerek private).
     */
    public static function bugun(): Carbon
    {
        return Carbon::now(self::GUN_DILIMI);
    }

    /**
     * Ekrana basılacak duvar saatine çevrilmiş Carbon; boş girdide null.
     *
     * Gelen değer bir Carbon ise KOPYALANIR: `setTimezone` nesneyi yerinde değiştirir ve
     * çağıranın elindeki modelin alanını sessizce kaydırmak, aynı isteğin başka bir yerinde
     * yapılan hesabı bozardı.
     */
    private static function gun(Carbon|string|null $tarih): ?Carbon
    {
        if ($tarih === null || $tarih === '') {
            return null;
        }

        $c = $tarih instanceof Carbon ? $tarih->copy() : Carbon::parse($tarih);

        return $c->setTimezone(self::GUN_DILIMI);
    }

    /** Kuruş → '1.250,50 ₺' (panelin geri kalanıyla aynı biçim; bkz. components/kurus.blade.php). */
    public static function tl(int $kurus): string
    {
        return number_format($kurus / 100, 2, ',', '.').' ₺';
    }

    /** İşaretli sunum (tasarımın `paraNet`i): '+1.250,50 ₺' / '−850,00 ₺'. Eksi işareti U+2212. */
    public static function tlNet(int $kurus): string
    {
        return ($kurus < 0 ? '−' : '+').self::tl(abs($kurus));
    }

    /**
     * Girdi ön dolgusu: 125050 → '1250,50'. BİNLİK AYRAÇ KOYULMAZ — kullanıcı alanın üstüne
     * yazarken '1.250,50' de yazabilir, o da kabul edilir (bkz. kurus()), ama biz belirsiz bir
     * değeri ekrana kendimiz koymayız.
     */
    public static function lira(int $kurus): string
    {
        return number_format($kurus / 100, 2, ',', '');
    }

    /**
     * TL metni → kuruş. Çözülemezse null (çağıran doğrulama hatası basar; sessizce 0 DÖNMEZ —
     * sıfır tutarlı bir ödeme, servis tarafından reddedilir ama kullanıcı neden reddedildiğini
     * anlamazdı).
     *
     * Esnaf klavyesi tek biçimli değildir; hepsi kabul edilir:
     *   '1250'  '1250,50'  '1.250,50'  '1250.50'  '1,250.50'  '1.250'  '₺ 1.250,50'
     *
     * AYRAÇ KARARI:
     *  - İkisi de varsa SON gelen ondalıktır ('1.250,50' → virgül; '1,250.50' → nokta).
     *  - Yalnız virgül varsa ondalıktır (Türkçe yazım).
     *  - Yalnız TEK nokta varsa: ardından TAM 3 hane geliyorsa BİNLİKtir ('1.250' = 1250 ₺),
     *    değilse ondalıktır ('45.50' = 45,50 ₺). Bu tek belirsiz durumdur ve Türkçe yazımda
     *    '1.250'in bin iki yüz elli olması, bir buçuk kuruş olmasından kıyaslanamayacak kadar
     *    olasıdır.
     *  - Birden çok virgül belirsizdir → reddedilir (0 varsaymak parayı sessizce değiştirirdi).
     */
    public static function kurus(string $ham): ?int
    {
        $t = str_replace(["\u{00A0}", ' ', '₺'], '', trim($ham));
        if ($t === '') {
            return null;
        }

        $negatif = str_starts_with($t, '-');
        $t = ltrim($t, '+-');

        if (! preg_match('/^[0-9]+([.,][0-9]+)*$/', $t)) {
            return null;
        }

        $noktalar = substr_count($t, '.');
        $virguller = substr_count($t, ',');

        if ($noktalar > 0 && $virguller > 0) {
            $ondalik = strrpos($t, ',') > strrpos($t, '.') ? ',' : '.';
        } elseif ($virguller > 1) {
            return null;
        } elseif ($virguller === 1) {
            $ondalik = ',';
        } elseif ($noktalar === 1) {
            $ondalik = (strlen($t) - (int) strrpos($t, '.') - 1) === 3 ? null : '.';
        } else {
            $ondalik = null;
        }

        if ($ondalik === null) {
            $sayi = str_replace(['.', ','], '', $t);
        } elseif ($ondalik === ',') {
            $sayi = str_replace(',', '.', str_replace('.', '', $t));
        } else {
            $sayi = str_replace(',', '', $t);
        }

        $kurus = (int) round(((float) $sayi) * 100);

        return $negatif ? -$kurus : $kurus;
    }

    /**
     * "Kapsadığı dönem" açılır listesi: bugünden 2 ay geri, 9 ay ileri (12 seçenek).
     *
     * TASARIMDAN SAPMA (bilinçli): prototip `AYLAR.map(a => a + ' 2026')` ile SABİT yılın 12 ayını
     * basıyordu. Ocak başında Aralık aboneliğinin tahsilatı girilemezdi; pencere bugüne göre
     * kayıyor, seçenek sayısı aynı kalıyor.
     *
     * @return array<string, string> ['2026-08' => 'Ağustos 2026', ...]
     */
    public static function donemSecenekleri(?Carbon $bugun = null): array
    {
        $bas = ($bugun ?? Carbon::now())->copy()->startOfMonth()->subMonths(2);

        $liste = [];
        for ($i = 0; $i < 12; $i++) {
            $ay = $bas->copy()->addMonths($i);
            $liste[$ay->format('Y-m')] = self::ayAdi($ay->format('Y-m'));
        }

        return $liste;
    }
}
