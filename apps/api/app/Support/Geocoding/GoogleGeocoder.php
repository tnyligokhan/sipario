<?php

namespace App\Support\Geocoding;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Google Geocoding API. Anahtar geldiğinde `GEOCODING_DRIVER=google` yeter — kodun başka
 * hiçbir yeri değişmez, mobil taraf farkı görmez.
 *
 * Yandex'ten iki fark: koordinat açık adlı alanlardan (`lat`/`lng`) okunur, sıra tuzağı yoktur;
 * ve hata HTTP koduyla değil gövdedeki `status` ile bildirilir — 200 dönen bir yanıt pekâlâ
 * "REQUEST_DENIED" olabilir, o yüzden başarı `successful()` ile ölçülmez.
 */
final class GoogleGeocoder implements Geocoder
{
    public function __construct(
        private readonly string $apiKey,
        private readonly string $baseUrl,
        private readonly int $timeout,
        private readonly string $ulke,
        private readonly string $bbox,
    ) {}

    public function hazirMi(): bool
    {
        return $this->apiKey !== '';
    }

    /** @return list<GeoAday> */
    public function ara(string $sorgu, int $enFazla): array
    {
        if (! $this->hazirMi()) {
            throw GeocodingException::yapilandirilmamis();
        }

        $parametreler = [
            'address' => $sorgu,
            'key' => $this->apiKey,
            'language' => 'tr',
            'region' => $this->ulke,
            'components' => 'country:'.strtoupper($this->ulke),
        ];

        $sinir = $this->bounds();
        if ($sinir !== null) {
            $parametreler['bounds'] = $sinir;
        }

        try {
            $yanit = Http::timeout($this->timeout)->acceptJson()->get($this->baseUrl, $parametreler);
        } catch (ConnectionException) {
            throw GeocodingException::ulasilamadi();
        }

        if (! $yanit->successful()) {
            Log::warning('Google geocoder beklenmedik yanıt', ['status' => $yanit->status()]);

            throw GeocodingException::ulasilamadi();
        }

        /** @var mixed $govde */
        $govde = $yanit->json();
        $durum = data_get($govde, 'status');
        $durum = is_string($durum) ? $durum : 'UNKNOWN_ERROR';

        // "Sonuç yok" ARIZA DEĞİLDİR: kullanıcı adresi düzeltebilsin diye boş listeyle döner.
        if ($durum === 'ZERO_RESULTS') {
            return [];
        }

        if ($durum !== 'OK') {
            Log::warning('Google geocoder hata durumu', ['status' => $durum]);

            throw in_array($durum, ['REQUEST_DENIED', 'INVALID_REQUEST', 'OVER_QUERY_LIMIT', 'OVER_DAILY_LIMIT'], true)
                ? GeocodingException::reddedildi()
                : GeocodingException::ulasilamadi();
        }

        return $this->ayristir($govde, $enFazla);
    }

    /**
     * @param  mixed  $govde
     * @return list<GeoAday>
     */
    private function ayristir($govde, int $enFazla): array
    {
        /** @var mixed $sonuclar */
        $sonuclar = data_get($govde, 'results');
        if (! is_array($sonuclar)) {
            return [];
        }

        $adaylar = [];
        /** @var mixed $sonuc */
        foreach ($sonuclar as $sonuc) {
            if (count($adaylar) >= $enFazla) {
                break;
            }

            $metin = data_get($sonuc, 'formatted_address');
            $lat = data_get($sonuc, 'geometry.location.lat');
            $lng = data_get($sonuc, 'geometry.location.lng');

            if (! is_string($metin) || $metin === '' || ! is_numeric($lat) || ! is_numeric($lng)) {
                continue;
            }

            if ($this->fazlaGenis($sonuc)) {
                continue;
            }

            $aday = new GeoAday(
                metin: $metin,
                lat: (float) $lat,
                lng: (float) $lng,
                kesinlik: $this->kesinlik(
                    is_string($tip = data_get($sonuc, 'geometry.location_type')) ? $tip : '',
                    data_get($sonuc, 'partial_match') === true,
                ),
                kaynak: GeoAday::KAYNAK_GOOGLE,
            );

            if ($aday->turkiyedeMi()) {
                $adaylar[] = $aday;
            }
        }

        return $adaylar;
    }

    /**
     * Ülke/il düzeyindeki sonuç TESLİMAT ADRESİ DEĞİLDİR — listeye hiç girmez.
     *
     * ÖLÇÜLDÜ (2026-07-29, gerçek istek): `"zzzqqq bulunmayan adres 12345"` sorgusuna Google
     * `ZERO_RESULTS` DEĞİL, `status=OK` ile **"Türkiye"** döndürüyor (`types=country/political`,
     * 38.96,35.24 — ülkenin coğrafi merkezi, Kırşehir civarı). O koordinat Türkiye sınırları
     * İÇİNDE olduğu için `turkiyedeMi()` süzgecinden geçiyor ve aday listesine giriyordu.
     *
     * Zararı somut: bayi anlamsız/eksik bir adres yazdığında listede "Türkiye" adayı belirir;
     * yanlışlıkla seçilirse müşterinin konumu ülkenin ortasına yazılır ve kurye bir daha
     * o kapıyı bulamaz. Üstelik hiçbir şey hata vermez — bu depoda en pahalıya mal olan
     * arıza türü tam olarak budur (kod çalışır, sonuç yalandır).
     *
     * Yandex aynı sorguya boş liste döndüğü için bu tuzak tek sağlayıcıyla hiç görünmemişti.
     *
     * @param  mixed  $sonuc
     */
    private function fazlaGenis($sonuc): bool
    {
        /** @var mixed $tipler */
        $tipler = data_get($sonuc, 'types');
        if (! is_array($tipler)) {
            return false;
        }

        // İl (`administrative_area_level_1`) de elenir: "Antalya" merkezine pin atmak bir
        // teslimat adresi değildir. İlçe/mahalle (`locality` ve altı) KALIR — onlar `semt`
        // kesinliğinde meşru bir yaklaşık cevaptır.
        return array_intersect(['country', 'administrative_area_level_1'], $tipler) !== [];
    }

    /**
     * Yapılandırmadaki "lon,lat~lon,lat" kutusunu Google'ın beklediği
     * "guneyBatiLat,guneyBatiLng|kuzeyDoguLat,kuzeyDoguLng" biçimine çevirir. Bozuk yapılandırma
     * özelliği DÜŞÜRMEZ, yalnız ipucunu atlar.
     */
    private function bounds(): ?string
    {
        $koseler = explode('~', $this->bbox);
        if (count($koseler) !== 2) {
            return null;
        }

        $sol = explode(',', $koseler[0]);
        $sag = explode(',', $koseler[1]);
        if (count($sol) !== 2 || count($sag) !== 2) {
            return null;
        }

        foreach ([$sol[0], $sol[1], $sag[0], $sag[1]] as $deger) {
            if (! is_numeric($deger)) {
                return null;
            }
        }

        return $sol[1].','.$sol[0].'|'.$sag[1].','.$sag[0];
    }

    /**
     * `location_type` → kesinlik. Yandex'teki kapı-numarası geri çekilmesinin Google karşılığı
     * BURADADIR ve ikinci bir sorgu gerektirmez: Google numarayı bulamadığında sıfır sonuç
     * dönmek yerine sokağı döner ve kaydı `partial_match: true` diye işaretler.
     *
     * O bayrak varken kesinlik en fazla `sokak`tır — `location_type` "ROOFTOP" dese bile.
     * Google'ın "rooftop"u sorgunun TAMAMINI değil eşleşebildiği kadarını anlatır; istenen
     * kapıyı değil sokağı bulmuşken bunu "bina" diye sunmak kuryenin güvendiği bir yalan
     * olurdu (DECISIONS.md — kapı numarası kararıyla aynı gerekçe).
     */
    private function kesinlik(string $tip, bool $kismiEslesme): string
    {
        $kesinlik = match ($tip) {
            'ROOFTOP', 'RANGE_INTERPOLATED' => GeoAday::KESINLIK_BINA,
            'GEOMETRIC_CENTER' => GeoAday::KESINLIK_SOKAK,
            default => GeoAday::KESINLIK_SEMT,
        };

        return ($kismiEslesme && $kesinlik === GeoAday::KESINLIK_BINA)
            ? GeoAday::KESINLIK_SOKAK
            : $kesinlik;
    }
}
