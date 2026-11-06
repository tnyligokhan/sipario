<?php

namespace App\Support\Route;

/**
 * Google "encoded polyline" biçimini noktalara çözer (Google'ın yayımladığı algoritma).
 *
 * Neden sunucuda: istemci tek bir biçim görsün — nokta listesi. Çözümü telefona taşımak, aynı
 * algoritmanın ikinci bir kopyasını (ve ikinci bir hata yerini) doğururdu.
 *
 * Bozuk girdide istisna atar: yarım bir çizgi haritada yanlış yere giden bir yol çizer, hiç
 * çizgi olmaması (istemci düz çizgiye düşer) ondan iyidir.
 */
final class PolylineCozucu
{
    /**
     * @return list<array{0: float, 1: float}> [enlem, boylam] çiftleri
     *
     * @throws RotaException
     */
    public static function coz(string $kodlu): array
    {
        $noktalar = [];
        $i = 0;
        $uzunluk = strlen($kodlu);
        $lat = 0;
        $lng = 0;

        while ($i < $uzunluk) {
            $lat += self::deger($kodlu, $i, $uzunluk);
            $lng += self::deger($kodlu, $i, $uzunluk);
            $noktalar[] = [$lat / 1e5, $lng / 1e5];
        }

        return $noktalar;
    }

    /** Tek bir değişken uzunluklu tamsayıyı okur ve konumu ilerletir. */
    private static function deger(string $kodlu, int &$i, int $uzunluk): int
    {
        $sonuc = 0;
        $kaydirma = 0;
        do {
            if ($i >= $uzunluk) {
                throw RotaException::beklenmedikYanit();
            }
            $bayt = ord($kodlu[$i++]) - 63;
            if ($bayt < 0) {
                throw RotaException::beklenmedikYanit();
            }
            $sonuc |= ($bayt & 0x1F) << $kaydirma;
            $kaydirma += 5;
        } while ($bayt >= 0x20 && $kaydirma < 35);

        return ($sonuc & 1) ? ~($sonuc >> 1) : ($sonuc >> 1);
    }
}
