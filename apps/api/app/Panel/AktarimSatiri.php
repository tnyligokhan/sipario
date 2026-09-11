<?php

namespace App\Panel;

use App\Support\Sync\FavoriUrunler;

/**
 * Müşteri CSV aktarımında TEK BİR SATIR — hücreleri okur, normalleştirir ve kendi geçerliliğini
 * söyler. `PanelImportService` yalnız orkestrasyon yapar; satırın ne olduğu buraya aittir.
 *
 * NEDEN AYRI SINIF: servis 359 satırdı ve çoklu telefon/adres, müşteri kodu ve favori ürün
 * sütunları eklenince 500 satır sınırını aşacaktı — bu depoda o sınır bir üslup tercihi değil,
 * sınıfın okunabilir kalmasının kapısıdır (FavoriUrunler ve UrunSecenekleri aynı gerekçeyle
 * ayrıldı). Ayrıca satırın DURUMU (hücreler) ile onun üzerinde işleyen DAVRANIŞ (ayrıştırma,
 * doğrulama) aynı nesnede kapsüllenir; dışarıya dar bir yüzey açılır.
 *
 * ÇOK DEĞERLİ HÜCRELER: bir müşterinin birden çok telefonu ve adresi olabilir (`customer_phones`
 * ve `customer_addresses` 1NF'dir — DECISIONS). Tek hücrede taşımak için ayraç gerekir ve o ayraç
 * GERÇEK VERİDE GEÇMEMELİDİR: adres virgül, noktalı virgül ve tire taşır, telefon eksi ve boşluk
 * taşır. ':::' üçlüsü hiçbirinde geçmez — üstelik Google Kişiler dışa aktarımı da çoklu numarayı
 * aynı ayraçla verir, yani bayinin elindeki dosya zaten bu biçimdedir.
 */
final class AktarimSatiri
{
    /** Çok değerli hücrelerin ayracı (telefon, adres, favori ürün). */
    public const AYRAC = ':::';

    /**
     * `customers.name` 160'tır; şablon sınırı bilerek DAR tutulur. Kolon genişliğini aşan bir
     * değer `push()`a giderse Postgres `22001` verir ve o SQLSTATE `CLIENT_DATA_SQLSTATES`
     * listesinde OLMADIĞI için tek olay reddedilmez — TÜM PARTİ geri alınır. Yani tek satırdaki
     * uzun bir ad, 9.000 satırlık aktarımın tamamını sessizce çöpe atardı.
     */
    private const AZAMI_AD = 120;

    /** `customer_addresses.region` kolonu. */
    private const AZAMI_BOLGE = 80;

    /** `products.name` kolonu — favori sütunundaki ad bunu aşarsa ürün yaratılamaz. */
    private const AZAMI_URUN_ADI = 160;

    /**
     * `customers.code` PostgreSQL `integer`dır (int4). Tavanı AŞAN bir değer `22003` üretir ve
     * bu kod `SyncService::CLIENT_DATA_SQLSTATES` listesinde olmadığı için TÜM parti geri alınır —
     * tek satırdaki saçma bir numara yüzünden binlerce müşteri yazılmaz. Sınır burada, satır
     * numarasıyla raporlanabildiği yerde uygulanır.
     */
    private const AZAMI_KOD = 2147483647;

    public readonly string $ad;

    public readonly string $bolge;

    public readonly string $not;

    public readonly ?int $kod;

    /** @var list<string> E.164'e çevrilmiş numaralar; ilki birincildir. */
    public readonly array $telefonlar;

    /** @var list<string> */
    public readonly array $adresler;

    /** @var list<string> Favori ürün ADLARI (kimlik değil — ürünler aktarım sırasında çözülür). */
    public readonly array $favoriler;

    /** @var list<string> Okunamayan telefon hücreleri — hata mesajında gösterilir. */
    private readonly array $bozukTelefonlar;

    private readonly bool $kodBozuk;

    /** @param list<string> $hucreler */
    public function __construct(public readonly int $satirNo, array $hucreler)
    {
        $this->ad = trim($hucreler[0] ?? '');
        $this->bolge = trim($hucreler[3] ?? '');
        $this->not = trim($hucreler[4] ?? '');

        [$this->telefonlar, $this->bozukTelefonlar] = self::telefonlariAyikla($hucreler[1] ?? '');
        $this->adresler = self::parcala($hucreler[2] ?? '');
        $this->favoriler = self::parcala($hucreler[6] ?? '');

        [$this->kod, $this->kodBozuk] = self::kodAyikla($hucreler[5] ?? '');
    }

    /**
     * Dedup ve arayan tanıma anahtarı: numaraların son 10 hanesi.
     *
     * @return list<string>
     */
    public function son10lar(): array
    {
        $anahtarlar = [];
        foreach ($this->telefonlar as $telefon) {
            $son10 = Telefon::son10($telefon);
            if ($son10 !== null) {
                $anahtarlar[] = $son10;
            }
        }

        return array_values(array_unique($anahtarlar));
    }

    /**
     * Satırın kendi hatası (çakışma/dedup DEĞİL — onu servis bilir, dosyanın tamamını gören odur).
     * Sırası bilinçli: önce kullanıcının GÖRECEĞİ alan (ad), sonra sessiz veri bozanlar.
     */
    public function hata(): ?string
    {
        if ($this->ad === '') {
            return 'Ad boş.';
        }
        if (mb_strlen($this->ad) < 2) {
            return 'Ad çok kısa (en az 2 karakter).';
        }
        if (mb_strlen($this->ad) > self::AZAMI_AD) {
            return 'Ad çok uzun (en fazla '.self::AZAMI_AD.' karakter).';
        }
        if (mb_strlen($this->bolge) > self::AZAMI_BOLGE) {
            return 'Bölge çok uzun (en fazla '.self::AZAMI_BOLGE.' karakter).';
        }
        if ($this->bozukTelefonlar !== []) {
            return 'Telefon okunamadı: "'.implode('", "', $this->bozukTelefonlar).'"';
        }
        if ($this->kodBozuk) {
            return 'Müşteri kodu 1 ile '.self::AZAMI_KOD.' arasında bir tam sayı olmalı.';
        }
        if (count($this->favoriler) > FavoriUrunler::AZAMI) {
            return 'En fazla '.FavoriUrunler::AZAMI.' favori ürün olabilir.';
        }
        foreach ($this->favoriler as $urun) {
            if (mb_strlen($urun) > self::AZAMI_URUN_ADI) {
                return 'Favori ürün adı çok uzun (en fazla '.self::AZAMI_URUN_ADI.' karakter).';
            }
        }

        return null;
    }

    /**
     * Önizleme ekranının okuduğu düz gösterim. Çoklu alanlar ayraçla birleştirilir — kullanıcı
     * dosyasında ne yazdıysa onu görmeli; sayıya indirgemek ("3 telefon") satırı denetlenemez kılar.
     *
     * @return array<string, mixed>
     */
    public function ozet(): array
    {
        return [
            'satir' => $this->satirNo,
            'ad' => $this->ad,
            'telefon' => implode(' '.self::AYRAC.' ', $this->telefonlar),
            'adres' => implode(' '.self::AYRAC.' ', $this->adresler),
            'bolge' => $this->bolge,
            'not' => $this->not,
            'kod' => $this->kod,
            'favoriler' => implode(', ', $this->favoriler),
        ];
    }

    // ------------------------------------------------------------------------------------

    /** @return list<string> */
    private static function parcala(string $hucre): array
    {
        $parcalar = [];
        foreach (explode(self::AYRAC, $hucre) as $parca) {
            $temiz = trim($parca);
            if ($temiz !== '' && ! in_array($temiz, $parcalar, true)) {
                $parcalar[] = $temiz;
            }
        }

        return $parcalar;
    }

    /**
     * Numaraları E.164'e çevirir. Okunamayanlar SESSİZCE ATILMAZ, ayrı listeye düşer: bir
     * numarayı yutup "aktarıldı" demek, arayan tanımanın o müşteride kör kalması demektir ve
     * bayi bunu ancak telefon çaldığında fark eder.
     *
     * Aynı numara iki kez yazılmışsa (Google dışa aktarımında sık) bir kez alınır — çift satır
     * müşterinin altında yığılırdı.
     *
     * @return array{list<string>, list<string>}
     */
    private static function telefonlariAyikla(string $hucre): array
    {
        $temiz = [];
        $bozuk = [];
        $gorulen = [];

        foreach (self::parcala($hucre) as $ham) {
            $e164 = Telefon::e164($ham);
            if ($e164 === null) {
                $bozuk[] = $ham;

                continue;
            }
            $anahtar = Telefon::son10($e164) ?? $e164;
            if (in_array($anahtar, $gorulen, true)) {
                continue;
            }
            $gorulen[] = $anahtar;
            $temiz[] = $e164;
        }

        return [$temiz, $bozuk];
    }

    /** @return array{?int, bool} [kod, bozuk mu] */
    private static function kodAyikla(string $hucre): array
    {
        $ham = trim($hucre);
        if ($ham === '') {
            return [null, false];
        }
        if (preg_match('/^\d+$/', $ham) !== 1) {
            return [null, true];
        }
        $kod = (int) $ham;

        return ($kod >= 1 && $kod <= self::AZAMI_KOD) ? [$kod, false] : [null, true];
    }
}
