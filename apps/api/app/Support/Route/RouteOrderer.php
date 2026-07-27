<?php

namespace App\Support\Route;

/**
 * Rota sıralayıcı — tasarım `s-siparisler.jsx`: "Oto Sırala (rota) · N hak".
 *
 * SAF: veritabanı, HTTP ve Laravel bilmez; girdi noktalar, çıktı sıradır. Böylece kurallar
 * (koordinatsız durak, tek durak, aynı nokta) ucuz birim testlerle sabitlenir.
 *
 * ALGORİTMA — en yakın komşu (nearest neighbour) zinciri:
 *   1. Listenin İLK durağı sabit kalır (kurye ilk nereye gidiyorsa oradan başlar).
 *   2. Her adımda kalanların içinden en yakını seçilir.
 *   3. Koordinatı OLMAYAN duraklar sıralamaya girmez; sona, aralarındaki göreli sıra
 *      korunarak eklenir ve sayıları çağırana bildirilir (UI kullanıcıya söyler).
 *
 * NEDEN OPTİMAL DEĞİL, NEDEN YETERLİ: gerçek gezgin-satıcı çözümü NP-zor; bir bayinin
 * günlük 10-40 durağında en yakın komşu, ele göre kurulan sıraya kıyasla belirgin kazanç
 * verir ve milisaniyede biter. Depo (dükkân) konumu şemada YOK — o yüzden başlangıç noktası
 * uydurulmaz, listenin ilk durağı korunur. Depo alanı eklenirse burası tek satırda değişir.
 */
class RouteOrderer
{
    /**
     * @param  list<array{id: string, lat: float|null, lng: float|null}>  $duraklar
     * @return array{order: list<string>, without_location: int}
     */
    public static function sirala(array $duraklar): array
    {
        $konumlu = [];
        $konumsuz = [];
        foreach ($duraklar as $d) {
            if ($d['lat'] === null || $d['lng'] === null) {
                $konumsuz[] = $d['id'];
            } else {
                $konumlu[] = $d;
            }
        }

        $sira = [];
        if ($konumlu !== []) {
            // İlk durak sabit; kalanlar her adımda en yakınına zincirlenir.
            $mevcut = array_shift($konumlu);
            $sira[] = $mevcut['id'];

            while ($konumlu !== []) {
                $enYakinDizin = 0;
                $enKisa = self::mesafe($mevcut, $konumlu[0]);
                foreach ($konumlu as $i => $aday) {
                    $d = self::mesafe($mevcut, $aday);
                    if ($d < $enKisa) {
                        $enKisa = $d;
                        $enYakinDizin = $i;
                    }
                }
                $mevcut = $konumlu[$enYakinDizin];
                $sira[] = $mevcut['id'];
                array_splice($konumlu, $enYakinDizin, 1);
            }
        }

        return [
            'order' => [...$sira, ...$konumsuz],
            'without_location' => count($konumsuz),
        ];
    }

    /**
     * Karesel mesafe (karekök alınmaz — yalnız KARŞILAŞTIRMA için kullanılıyor, sıralama aynı).
     * Boylam enlemle daraldığı için cos(enlem) ile ölçeklenir: Antalya'da 1° boylam ≈ 1° enlemin
     * %80'i kadardır, bu düzeltme olmadan doğu-batı mesafeler olduğundan uzun sayılır.
     *
     * @param  array{id: string, lat: float|null, lng: float|null}  $a
     * @param  array{id: string, lat: float|null, lng: float|null}  $b
     */
    private static function mesafe(array $a, array $b): float
    {
        $olcek = cos(deg2rad(((float) $a['lat'] + (float) $b['lat']) / 2));
        $dLat = (float) $a['lat'] - (float) $b['lat'];
        $dLng = ((float) $a['lng'] - (float) $b['lng']) * $olcek;

        return $dLat * $dLat + $dLng * $dLng;
    }
}
