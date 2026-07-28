<?php

namespace App\Support\Geocoding;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Yandex Geocoder (HTTP API). Türkiye adreslerinde serbest metin ayrıştırması güçlüdür —
 * esnafın yazdığı "bahçelievler mah 5. sok no12 d3" gibi girdileri çözebilen az sayıda
 * servisten biri; ilk sağlayıcı olarak bu yüzden seçildi (DECISIONS).
 *
 * DİKKAT — `Point.pos` "BOYLAM ENLEM" sırasındadır (lng lat), coğrafyada alışılanın TERSİ.
 * Burada ters okunursa Antalya'daki bir adres Hindistan'a düşer ve rota sessizce saçmalar;
 * bu yüzden ayrıştırma tek yerde durur ve testle kilitlenir.
 */
final class YandexGeocoder implements Geocoder
{
    public function __construct(
        private readonly string $apiKey,
        private readonly string $baseUrl,
        private readonly int $timeout,
        private readonly string $lang,
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

        try {
            $yanit = Http::timeout($this->timeout)
                ->acceptJson()
                ->get($this->baseUrl, [
                    'apikey' => $this->apiKey,
                    'geocode' => $sorgu,
                    'format' => 'json',
                    'results' => $enFazla,
                    'lang' => $this->lang,
                    // bbox arama merkezini Türkiye'ye çeker; rspn=0 ile SINIR DEĞİLDİR (sadece
                    // öncelik) — sınır dışına düşen sonuç zaten GeoAday::turkiyedeMi ile elenir.
                    'bbox' => $this->bbox,
                    'rspn' => 0,
                ]);
        } catch (ConnectionException) {
            throw GeocodingException::ulasilamadi();
        }

        if ($yanit->status() === 403 || $yanit->status() === 401) {
            // Anahtar geçersiz / kota bitti. Ham gerekçe İSTEMCİYE GİTMEZ, log'a yazılır.
            Log::warning('Yandex geocoder isteği reddetti', ['status' => $yanit->status()]);

            throw GeocodingException::reddedildi();
        }

        if (! $yanit->successful()) {
            Log::warning('Yandex geocoder beklenmedik yanıt', ['status' => $yanit->status()]);

            throw GeocodingException::ulasilamadi();
        }

        return $this->ayristir($yanit->json());
    }

    /**
     * Yandex GeoObjectCollection → GeoAday listesi. Beklenmedik/eksik alan sessizce ATLANIR:
     * tek bozuk kayıt yüzünden bütün listeyi düşürmek kullanıcıyı boş yere adressiz bırakırdı.
     *
     * @param  mixed  $govde
     * @return list<GeoAday>
     */
    private function ayristir($govde): array
    {
        if (! is_array($govde)) {
            return [];
        }

        /** @var mixed $uyeler */
        $uyeler = data_get($govde, 'response.GeoObjectCollection.featureMember');
        if (! is_array($uyeler)) {
            return [];
        }

        $adaylar = [];
        /** @var mixed $uye */
        foreach ($uyeler as $uye) {
            $nesne = data_get($uye, 'GeoObject');
            if (! is_array($nesne)) {
                continue;
            }

            $pos = data_get($nesne, 'Point.pos');
            if (! is_string($pos)) {
                continue;
            }

            // "30.713 36.896" — BOYLAM önce.
            $parcalar = preg_split('/\s+/', trim($pos)) ?: [];
            if (count($parcalar) < 2 || ! is_numeric($parcalar[0]) || ! is_numeric($parcalar[1])) {
                continue;
            }

            $meta = data_get($nesne, 'metaDataProperty.GeocoderMetaData');
            $metin = data_get($meta, 'text');
            if (! is_string($metin) || $metin === '') {
                // Metinsiz aday kullanıcıya gösterilemez ("hangisini seçiyorum?").
                continue;
            }

            $aday = new GeoAday(
                metin: $this->kisalt($metin),
                lat: (float) $parcalar[1],
                lng: (float) $parcalar[0],
                kesinlik: $this->kesinlik(
                    is_string($p = data_get($meta, 'precision')) ? $p : '',
                    is_string($k = data_get($meta, 'kind')) ? $k : '',
                ),
            );

            if ($aday->turkiyedeMi()) {
                $adaylar[] = $aday;
            }
        }

        return $adaylar;
    }

    /**
     * Yandex her metne "Türkiye, " ön eki koyar; kurye listesinde bu 8 karakter her satırda
     * tekrar eder ve asıl ayırt edici kısmı (mahalle/sokak) ekrandan taşırır.
     */
    private function kisalt(string $metin): string
    {
        foreach (['Türkiye, ', 'Turkey, '] as $onEk) {
            if (str_starts_with($metin, $onEk)) {
                return substr($metin, strlen($onEk));
            }
        }

        return $metin;
    }

    /** Yandex `precision`/`kind` → bizim üç kademe. */
    private function kesinlik(string $precision, string $kind): string
    {
        if ($precision === 'exact' || $precision === 'number' || $kind === 'house') {
            return GeoAday::KESINLIK_BINA;
        }

        if ($precision === 'near' || $precision === 'range' || $precision === 'street'
            || $kind === 'street') {
            return GeoAday::KESINLIK_SOKAK;
        }

        return GeoAday::KESINLIK_SEMT;
    }
}
