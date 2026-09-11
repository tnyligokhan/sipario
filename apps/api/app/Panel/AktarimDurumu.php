<?php

namespace App\Panel;

/**
 * Aktarım sırasında DOSYANIN TAMAMINI gören durum: hangi telefon/kod daha önce geçti, bayide
 * neler kayıtlı. Satırın kendi geçerliliğini `AktarimSatiri` bilir; ÇAKIŞMAYI ancak dosyayı
 * baştan sona izleyen bir nesne bilebilir — o yüzden karar burada verilir.
 *
 * DEDUP ANAHTARI SATIRA GÖRE DEĞİŞİR, ve bu ayrım pazarlıksızdır:
 *
 *  · KOD VARSA anahtar KODDUR, telefon değil. Gerekçe ölçüldü (2026-09-11, 9.057 satırlık gerçek
 *    bir devralma): 269 numara BİRDEN ÇOK müşteride geçiyordu — aile bireyleri, ev + işyeri,
 *    aynı numarayı veren komşular. Telefonla tekilleştirmek 442 gerçek müşteriyi "çift kayıt"
 *    sanıp atardı ve bayi bunu ancak o müşteri arayınca fark ederdi. Eski sistemin kodu, o
 *    sistemin kendi tekillik kararıdır; ona güvenmek numaraya güvenmekten doğrudur.
 *
 *  · KOD YOKSA anahtar eski davranıştaki gibi TELEFONUN SON 10 HANESİDİR. Kodsuz satırda
 *    güvenilecek başka bir kimlik yoktur ve elle doldurulmuş şablonlarda asıl risk aynı
 *    müşteriyi iki kez yazmaktır.
 *
 * KOD BAYİDE KULLANIMDAYSA SATIR 'hatali'DIR, sessizce kodsuz yazılmaz: `customers.code` kısmi
 * unique indekslidir (migration 801). Kodu düşürüp müşteriyi yine de yazmak, bayinin telefonda
 * aradığı numarayı sessizce başka birine bırakırdı — atlanan satır görünür, kayan kod görünmez.
 */
final class AktarimDurumu
{
    /** @var array<string, int> son10 → dosyada ilk görüldüğü satır */
    private array $dosyadakiTelefonlar = [];

    /** @var array<int, int> kod → dosyada ilk görüldüğü satır */
    private array $dosyadakiKodlar = [];

    /**
     * @param  array<string, string>  $mevcutTelefonlar  son10 → kayıtlı müşterinin adı
     * @param  array<int, string>  $mevcutKodlar  kod → kayıtlı müşterinin adı
     */
    public function __construct(
        private readonly array $mevcutTelefonlar,
        private readonly array $mevcutKodlar,
    ) {}

    /** @return array<string, mixed> */
    public function degerlendir(AktarimSatiri $satir): array
    {
        $temel = $satir->ozet();

        $hata = $satir->hata();
        if ($hata !== null) {
            return $temel + ['durum' => 'hatali', 'aciklama' => $hata];
        }

        $karar = $satir->kod !== null
            ? $this->kodaGore($satir)
            : $this->telefonaGore($satir);

        return $temel + $karar;
    }

    // ------------------------------------------------------------------------------------

    /** @return array<string, string> */
    private function kodaGore(AktarimSatiri $satir): array
    {
        $kod = (int) $satir->kod;

        if (isset($this->dosyadakiKodlar[$kod])) {
            return ['durum' => 'atlanacak',
                'aciklama' => 'Bu müşteri kodu dosyada '.$this->dosyadakiKodlar[$kod].'. satırda da var.'];
        }

        $sahip = $this->mevcutKodlar[$kod] ?? null;
        if ($sahip !== null) {
            /**
             * KOD BAYİDE VARSA İKİ AYRI DURUM VARDIR VE KARIŞTIRILAMAZ:
             *
             *  · AYNI müşteri → bu satır DAHA ÖNCE AKTARILMIŞ. 'atlanacak'. Bu, yarıda kalmış
             *    bir aktarımı sürdürmenin tek yoludur: kullanıcı aynı dosyayı yeniden yükler,
             *    yazılmış satırlar atlanır, eksikler girer. Bunu 'hatali' saymak kurtarma
             *    yolunu kapatır — üstelik SESSİZCE değil GÜRÜLTÜLÜ biçimde: 9.000 satırlık bir
             *    dosyayı sürdürmek isteyen kullanıcı "9.000 satır hatalı" görür ve aktarımın
             *    çöktüğünü sanır (ölçüldü: adımlı aktarımın kurtarma testi bu yüzden kırıldı).
             *
             *  · BAŞKA bir müşteri → gerçek çakışma. 'hatali' ve KİMDE olduğu söylenir. Kodu
             *    sessizce düşürüp müşteriyi yine de yazmak, bayinin telefonda aradığı numarayı
             *    başka birine bırakırdı.
             *
             * Ayrım ADA bakar. Zayıf görünür ama kapsamı dardır: aynı kodu taşıyan iki kaydın
             * adı da aynıysa bunlar zaten tek müşteridir ve atlamak doğru karardır.
             */
            return self::sade($sahip) === self::sade($satir->ad)
                ? ['durum' => 'atlanacak', 'aciklama' => 'Bu müşteri zaten aktarılmış (kod '.$kod.').']
                : ['durum' => 'hatali', 'aciklama' => 'Bu müşteri kodu bayide başka bir müşteride kullanılıyor: '.$sahip];
        }

        $this->dosyadakiKodlar[$kod] = $satir->satirNo;

        return ['durum' => 'eklenecek', 'aciklama' => ''];
    }

    /** Ad karşılaştırması: boşluk, noktalama ve büyük/küçük harf farkı müşteriyi değiştirmez. */
    private static function sade(string $ad): string
    {
        $buyuk = mb_strtoupper(trim($ad), 'UTF-8');

        return preg_replace('/[^\p{L}\p{N}]/u', '', $buyuk) ?? '';
    }

    /** @return array<string, string> */
    private function telefonaGore(AktarimSatiri $satir): array
    {
        $son10lar = $satir->son10lar();

        foreach ($son10lar as $son10) {
            if (isset($this->dosyadakiTelefonlar[$son10])) {
                return ['durum' => 'atlanacak',
                    'aciklama' => 'Bu numara dosyada '.$this->dosyadakiTelefonlar[$son10].'. satırda da var.'];
            }
            if (isset($this->mevcutTelefonlar[$son10])) {
                return ['durum' => 'atlanacak',
                    'aciklama' => 'Bu numara bayide kayıtlı: '.$this->mevcutTelefonlar[$son10]];
            }
        }

        foreach ($son10lar as $son10) {
            $this->dosyadakiTelefonlar[$son10] = $satir->satirNo;
        }

        return [
            'durum' => 'eklenecek',
            // Telefonsuz satır eklenir ama uyarılır: dedup anahtarı yoktur, dosya ikinci kez
            // aktarılırsa aynı müşteri tekrar doğar ve bunu kimse fark etmez.
            'aciklama' => $son10lar === [] ? 'Telefon yok — tekrar aktarımda çift kayıt riski.' : '',
        ];
    }
}
