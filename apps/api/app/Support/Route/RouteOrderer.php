<?php

namespace App\Support\Route;

/**
 * Rota sıralayıcı — tasarım `s-siparisler.jsx`: "Oto Sırala (rota) · N hak".
 *
 * SAF: veritabanı, HTTP ve Laravel bilmez; girdi noktalar, çıktı sıradır. Böylece kurallar
 * (koordinatsız durak, tek durak, aynı nokta) ucuz birim testlerle sabitlenir.
 *
 * ALGORİTMA — en yakın komşu (nearest neighbour) zinciri:
 *   1. Zincirin BAŞI: `$baslangic` verilmişse (cihazın anlık konumu) ona EN YAKIN durak;
 *      verilmemişse listenin İLK durağı sabit kalır.
 *   2. Her adımda kalanların içinden en yakını seçilir.
 *   3. Koordinatı OLMAYAN duraklar sıralamaya girmez; sona, aralarındaki göreli sıra
 *      korunarak eklenir ve sayıları çağırana bildirilir (UI kullanıcıya söyler).
 *
 * NEDEN OPTİMAL DEĞİL, NEDEN YETERLİ: gerçek gezgin-satıcı çözümü NP-zor; bir bayinin
 * günlük 10-40 durağında en yakın komşu, ele göre kurulan sıraya kıyasla belirgin kazanç
 * verir ve milisaniyede biter.
 *
 * BAŞLANGIÇ NOKTASI NEDEN OPSİYONEL: depo (dükkân) konumu şemada YOK. Kurye cihazı konumunu
 * verebiliyorsa gerçek başlangıç odur ve tur oradan kurulur. Veremiyorsa (izin yok, GPS kapalı,
 * eski istemci) başlangıç UYDURULMAZ — eski davranış birebir korunur, listenin ilk durağı sabit
 * kalır. Yanlış bir başlangıç noktası, hiç başlangıç noktası olmamasından daha kötü sıra üretir.
 */
class RouteOrderer
{
    /**
     * @param  list<array{id: string, lat: float|null, lng: float|null}>  $duraklar
     * @param  array{lat: float, lng: float}|null  $baslangic  Cihazın anlık konumu (opsiyonel).
     * @return array{order: list<string>, without_location: int}
     */
    public static function sirala(array $duraklar, ?array $baslangic = null): array
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
            // Zincirin başı: konum varsa ona en yakın durak, yoksa listenin ilk durağı.
            $ilk = $baslangic === null ? 0 : self::enYakinDizin($baslangic, $konumlu);
            $mevcut = $konumlu[$ilk];
            array_splice($konumlu, $ilk, 1);
            $sira[] = $mevcut['id'];

            // Kalanlar her adımda en yakınına zincirlenir.
            while ($konumlu !== []) {
                $enYakinDizin = self::enYakinDizin($mevcut, $konumlu);
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
     * Adaylar içinde [$nokta]ya en yakın olanın DİZİNİ. Liste boş çağrılmaz (çağıranlar kontrol eder).
     *
     * @param  array{lat: float|null, lng: float|null}  $nokta
     * @param  non-empty-list<array{id: string, lat: float|null, lng: float|null}>  $adaylar
     */
    private static function enYakinDizin(array $nokta, array $adaylar): int
    {
        $enYakin = 0;
        $enKisa = self::mesafe($nokta, $adaylar[0]);
        foreach ($adaylar as $i => $aday) {
            $d = self::mesafe($nokta, $aday);
            if ($d < $enKisa) {
                $enKisa = $d;
                $enYakin = $i;
            }
        }

        return $enYakin;
    }

    /**
     * Karesel mesafe (karekök alınmaz — yalnız KARŞILAŞTIRMA için kullanılıyor, sıralama aynı).
     * Boylam enlemle daraldığı için cos(enlem) ile ölçeklenir: Antalya'da 1° boylam ≈ 1° enlemin
     * %80'i kadardır, bu düzeltme olmadan doğu-batı mesafeler olduğundan uzun sayılır.
     *
     * @param  array{lat: float|null, lng: float|null}  $a
     * @param  array{lat: float|null, lng: float|null}  $b
     */
    private static function mesafe(array $a, array $b): float
    {
        $olcek = cos(deg2rad(((float) $a['lat'] + (float) $b['lat']) / 2));
        $dLat = (float) $a['lat'] - (float) $b['lat'];
        $dLng = ((float) $a['lng'] - (float) $b['lng']) * $olcek;

        return $dLat * $dLat + $dLng * $dLng;
    }
}
