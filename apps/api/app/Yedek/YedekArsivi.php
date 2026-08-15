<?php

namespace App\Yedek;

use Carbon\CarbonImmutable;

/**
 * Sunucudaki veritabanı yedeklerini OKUYAN katman.
 *
 * NEDEN VAR: yedekleri `backup` sidecar'ı üretiyor (`docker/backup/backup.sh`, günlük
 * `pg_dump | gzip`) ve bugüne kadar o dosyalara BAŞKA HİÇBİR ŞEY erişemiyordu — dosyalar
 * `sipario_backups` volume'ünde, yalnız sidecar'a bağlıydı. Yani yedek alınıyordu ama
 * ALINDIĞINI kimse göremiyor, indirilemiyordu. Bu sınıf o volume'ü `app`/`scheduler`
 * tarafına SALT-OKUNUR açar (`docker-compose.prod.yml`) ve üstüne iki iş yapar:
 * en yenisini bulmak, bir adı güvenle dosyaya çözmek.
 *
 * ⚠️ BU SINIFIN ÇÖZDÜĞÜ AD, KULLANICIDAN GELİR. `coz()` bu yüzden savunmanın kendisidir ve
 * üç ayrı kapıdan geçirir (bkz. metot başlığı). Buraya gevşetilmiş bir kontrol konursa
 * sonucu dizin dışına çıkan bir dosya okuması olur — `/etc/passwd` değil, çok daha kötüsü:
 * container içindeki HERHANGİ bir dosya, panele giren birine açılır.
 *
 * ⚠️ YEDEK DOSYASI ÜRÜNÜN EN YOĞUN KİŞİSEL VERİ TAŞIYICISIDIR — tüm bayilerin tüm
 * müşterileri, adresleri, telefonları tek dosyada. Bu yüzden indirme rotası `auth:admin`
 * ARKASINDADIR ve imzalı-link gibi "bağlantıyı bilen indirir" desenleri BİLEREK
 * kullanılmadı: e-posta kutusu ele geçen biri, imzalı linkle veritabanının tamamını alırdı.
 */
class YedekArsivi
{
    /** Sidecar'ın yazdığı üç kova. Saklama politikası: 7 günlük · 4 haftalık · 6 aylık. */
    private const KOVALAR = ['daily', 'weekly', 'monthly'];

    /**
     * Dosya adı deseni — sidecar'ın ürettiği biçimin AYNISI (`backup.sh:46`).
     *
     * Tarih/saat damgası desende zorunlu: bu, "adı `.sql.gz` ile biten her dosya" demekten
     * dar bir kapıdır ve dizine elle atılmış bir dosyanın indirilebilir olmasını engeller.
     */
    private const DESEN = '/^sipario_\d{8}_\d{6}\.sql\.gz$/';

    public function __construct(private readonly string $dizin) {}

    public static function varsayilan(): self
    {
        return new self((string) config('yedek.dizin', '/backups'));
    }

    /**
     * En yeni yedek — yoksa null.
     *
     * SIRALAMA ADA GÖRE, MTIME'A GÖRE DEĞİL: ad `sipario_YYYYMMDD_HHMMSS` biçiminde olduğu
     * için sözlük sırası = zaman sırası, ve bu dosya kopyalandığında (haftalık/aylık kova)
     * değişmez. `filemtime` ise kopyalamada tazelenir ve altı ay önceki bir aylık yedeği
     * "en yeni" gösterebilirdi.
     *
     * @return array{ad: string, yol: string, boyut: int, zaman: CarbonImmutable}|null
     */
    public function sonYedek(): ?array
    {
        $adlar = $this->adlar();

        if ($adlar === []) {
            return null;
        }

        return $this->bilgi(end($adlar));
    }

    /**
     * Arşivdeki tüm yedek adları — eskiden yeniye.
     *
     * @return list<string>
     */
    public function adlar(): array
    {
        $bulunan = [];

        foreach (self::KOVALAR as $kova) {
            $kovaDizini = $this->dizin.'/'.$kova;

            if (! is_dir($kovaDizini)) {
                continue;
            }

            foreach ((array) scandir($kovaDizini) as $ad) {
                if (is_string($ad) && preg_match(self::DESEN, $ad) === 1) {
                    // Aynı dosya haftalık/aylık kovaya KOPYALANIR (backup.sh:64,70) — ad
                    // anahtar yapılarak yinelenen kayıt tekilleştirilir.
                    $bulunan[$ad] = true;
                }
            }
        }

        $adlar = array_keys($bulunan);
        sort($adlar);

        return $adlar;
    }

    /**
     * Bir yedek adını GÜVENLE dosya yoluna çözer — çözemezse null.
     *
     * ÜÇ KAPI, sırayla:
     *   ① `basename` — gelen değerden dizin bileşenlerini söker (`../../etc/x` → `x`).
     *   ② DESEN — kalan ad sidecar'ın ürettiği biçime birebir uymalı. Bu kapı tek başına
     *      da yeterdi (desende `/` ve `.` yok), ama tek kapıya güvenmek bu depoda birkaç
     *      kez pahalıya patladı.
     *   ③ `realpath` + ön ek — sembolik bağ ihtimaline karşı, çözülen GERÇEK yolun arşiv
     *      dizininin altında kaldığı ölçülür. ①② bir gün gevşetilirse asıl duvar budur.
     */
    public function coz(string $ad): ?string
    {
        $temiz = basename($ad);

        if (preg_match(self::DESEN, $temiz) !== 1) {
            return null;
        }

        $kok = realpath($this->dizin);

        if ($kok === false) {
            return null;
        }

        foreach (self::KOVALAR as $kova) {
            $yol = realpath($this->dizin.'/'.$kova.'/'.$temiz);

            if ($yol === false || ! is_file($yol)) {
                continue;
            }

            if (! str_starts_with($yol, $kok.DIRECTORY_SEPARATOR)) {
                continue;
            }

            return $yol;
        }

        return null;
    }

    /**
     * @return array{ad: string, yol: string, boyut: int, zaman: CarbonImmutable}|null
     */
    public function bilgi(string $ad): ?array
    {
        $yol = $this->coz($ad);

        if ($yol === null) {
            return null;
        }

        return [
            'ad' => basename($yol),
            'yol' => $yol,
            'boyut' => (int) filesize($yol),
            'zaman' => $this->zamanDamgasi(basename($yol)),
        ];
    }

    /**
     * Adın içindeki damgayı zamana çevirir.
     *
     * Damga sidecar'ın `date` çıktısıdır ve sunucu UTC koşar; okuyucu Türkiye'dedir. Dönüşüm
     * BURADA yapılır ki e-postada "sabah 03:00'te alınmış" yazan bir yedek, aslında 06:00'da
     * alınmışken yanlış saatle görünmesin.
     */
    private function zamanDamgasi(string $ad): CarbonImmutable
    {
        $damga = substr($ad, strlen('sipario_'), 15); // YYYYMMDD_HHMMSS

        // `createFromFormat` başarısızlıkta `null` döner, `false` DEĞİL — ilk yazımda `false`
        // karşılaştırılmıştı ve o savunma hiçbir zaman çalışmayacaktı (phpstan yakaladı).
        // Ad zaten desenden geçmiş olduğu için bu dalın gerçekte tetiklenmesi beklenmez;
        // yine de duruyor, çünkü buradaki bir istisna günlük postayı komple düşürürdü.
        $zaman = CarbonImmutable::createFromFormat('Ymd_His', $damga, 'UTC');

        return ($zaman ?? CarbonImmutable::now('UTC'))->setTimezone('Europe/Istanbul');
    }
}
