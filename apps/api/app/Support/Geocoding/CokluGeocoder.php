<?php

namespace App\Support\Geocoding;

use Illuminate\Support\Facades\Log;

/**
 * BİRDEN ÇOK sağlayıcıyı aynı anda sorar ve adayları TEK listede birleştirir
 * (kullanıcı kararı 2026-07-29: *"hem Yandex hem Google gelsin, en doğrusunu kullanıcı seçsin"*).
 *
 * Neden iki sağlayıcı: ikisinin Türkiye verisi FARKLI yerlerde eksiktir. Yandex bina numarasını
 * katı eşleştirir ve numara kayıtlı değilse hiç sonuç vermez; Google numarayı bulamayınca sokağa
 * düşer ama bazı yeni mahalleleri hiç tanımaz. Tek sağlayıcıda "bulunamadı" demek zorunda
 * kaldığımız adreslerin bir kısmını diğeri biliyor.
 *
 * ÜÇ DAVRANIŞ KURALI:
 *
 * 1. **Bir sağlayıcının arızası özelliği DÜŞÜRMEZ.** Biri patlarsa (kota, anahtar, faturalandırma,
 *    ağ) diğerinin adayları yine döner ve arıza yalnız log'a yazılır. Uç nokta ancak HEPSİ
 *    düşerse 503 verir. Bu, "iki sağlayıcı" kararının asıl kazancıdır: yedeklilik.
 * 2. **Aynı noktayı gösteren adaylar BİRLEŞTİRİLİR** ve kaynağı `google+yandex` olur. Bu bir
 *    süsleme değil sinyaldir: iki bağımsız servis aynı kapıyı işaret ediyorsa o aday listenin
 *    en güvenilirdir ve BAŞA alınır.
 * 3. **Ayrışan adaylar SİLİNMEZ**, yan yana durur. Hangisinin doğru olduğuna sağlayıcı değil
 *    kullanıcı karar verir — özelliğin varlık sebebi bu.
 */
final class CokluGeocoder implements Geocoder
{
    /** @var list<array{ad: string, geocoder: Geocoder}> */
    private array $saglayicilar;

    /**
     * @param  list<array{ad: string, geocoder: Geocoder}>  $saglayicilar
     *                                                                     Sıra ÖNEMLİDİR: eşit koşulda önce yazılan sağlayıcının adayı üstte çıkar.
     */
    public function __construct(array $saglayicilar)
    {
        // Hazır olmayanı (anahtarsız) hiç tutmayız — her sorguda `yapilandirilmamis` fırlatıp
        // log'u kirletmesinin ve "kısmi arıza" sayılmasının anlamı yok.
        $this->saglayicilar = array_values(array_filter(
            $saglayicilar,
            fn (array $s) => $s['geocoder']->hazirMi()
        ));
    }

    public function hazirMi(): bool
    {
        return $this->saglayicilar !== [];
    }

    /** @return list<GeoAday> */
    public function ara(string $sorgu, int $enFazla): array
    {
        if (! $this->hazirMi()) {
            throw GeocodingException::yapilandirilmamis();
        }

        /** @var list<list<GeoAday>> $listeler */
        $listeler = [];
        $ilkArıza = null;

        foreach ($this->saglayicilar as $s) {
            try {
                // Her sağlayıcıdan TAM sayıda aday isteriz. Bölüştürseydik (ör. 2+3) biri boş
                // dönünce liste gereksiz kısalırdı; birleştirme sonunda zaten üst sınıra kırpılıyor.
                $listeler[] = $this->etiketle($s['geocoder']->ara($sorgu, $enFazla), $s['ad']);
            } catch (GeocodingException $e) {
                // ARIZAYI YUTMUYORUZ, ERTELİYORUZ: diğer sağlayıcı çalışıyorsa kullanıcı bunu
                // hiç görmemeli, ama sebebi log'da durmalı — sessizce yarım çalışan bir özellik
                // bu depoda en pahalı arıza türüdür.
                Log::warning('Coklu geocoder: bir saglayici dustu', [
                    'saglayici' => $s['ad'],
                    'sebep' => $e->getMessage(),
                ]);
                $ilkArıza ??= $e;
            }
        }

        // HEPSİ düştü → gerçekten arıza. Boş liste dönmek "bu adres yok" demek olurdu ve
        // kullanıcı var olan bir adresi düzeltmeye çalışarak vakit kaybederdi.
        if ($listeler === []) {
            throw $ilkArıza ?? GeocodingException::ulasilamadi();
        }

        return array_slice($this->birlestir($listeler), 0, $enFazla);
    }

    /**
     * @param  list<GeoAday>  $adaylar
     * @return list<GeoAday>
     */
    private function etiketle(array $adaylar, string $ad): array
    {
        return array_map(
            fn (GeoAday $a) => new GeoAday($a->metin, $a->lat, $a->lng, $a->kesinlik, $ad),
            $adaylar
        );
    }

    /**
     * Sağlayıcı listelerini tek listeye indirir.
     *
     * Sıra: önce SIRAYLA birer aday alınır (round-robin) — tek sağlayıcının bütün listeyi
     * doldurup diğerini üst sınırın dışına itmesini engeller, ki iki sağlayıcı kullanmanın
     * anlamı o zaman kalmazdı. Sonra aynı noktalar birleştirilir. En son, üzerinde MUTABAKAT
     * olan adaylar başa çekilir (kararlı sıralama — geri kalan round-robin sırasını korur).
     *
     * @param  list<list<GeoAday>>  $listeler
     * @return list<GeoAday>
     */
    private function birlestir(array $listeler): array
    {
        $sirali = [];
        $enUzun = max(array_map('count', $listeler));
        for ($i = 0; $i < $enUzun; $i++) {
            foreach ($listeler as $liste) {
                if (isset($liste[$i])) {
                    $sirali[] = $liste[$i];
                }
            }
        }

        /** @var list<GeoAday> $birlesik */
        $birlesik = [];
        foreach ($sirali as $aday) {
            $eslesen = null;
            foreach ($birlesik as $k => $var) {
                if ($var->ayniYerMi($aday)) {
                    $eslesen = $k;
                    break;
                }
            }

            if ($eslesen === null) {
                $birlesik[] = $aday;

                continue;
            }

            $birlesik[$eslesen] = $this->kaynastir($birlesik[$eslesen], $aday);
        }

        usort(
            $birlesik,
            fn (GeoAday $a, GeoAday $b) => $this->mutabakatVarMi($b) <=> $this->mutabakatVarMi($a)
        );

        return $birlesik;
    }

    /**
     * Aynı yeri gösteren iki adayı tek adaya indirir.
     *
     * Metin ve koordinat DAHA KESİN olandan alınır (bina > sokak > semt); eşitse ilk gelen
     * korunur. Kaynak ikisinin birleşimidir — bu alanın tek amacı kullanıcıya mutabakatı
     * göstermektir. Kesinlik de yükseğe çekilir: iki servisten biri binayı bulduysa nokta
     * gerçekten binadadır.
     */
    private function kaynastir(GeoAday $mevcut, GeoAday $yeni): GeoAday
    {
        $iyi = $yeni->kesinlikDerecesi() > $mevcut->kesinlikDerecesi() ? $yeni : $mevcut;

        $kaynaklar = array_unique(array_merge(
            explode('+', $mevcut->kaynak),
            explode('+', $yeni->kaynak),
        ));
        sort($kaynaklar);

        return new GeoAday(
            $iyi->metin,
            $iyi->lat,
            $iyi->lng,
            $iyi->kesinlik,
            implode('+', array_filter($kaynaklar)),
        );
    }

    private function mutabakatVarMi(GeoAday $aday): int
    {
        return str_contains($aday->kaynak, '+') ? 1 : 0;
    }
}
