<?php

namespace App\Support\Route;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Google Routes API — `computeRoutes` + `optimizeWaypointOrder`.
 *
 * NEDEN: yakın komşu KUŞ UÇUŞU ölçer. Şehirde iki kapı 300 m yakın olabilir ama arada nehir,
 * bölünmüş yol ya da tek yön varsa sürüş 4 km sürer. Google gerçek yol ağını ve tek yönleri
 * bilir; aynı duraklar için belirgin daha kısa tur çıkarır.
 *
 * HEDEF = BAŞLANGICA EN UZAK DURAK — sahada ölçülen bir arızanın düzeltmesi (2026-07-29).
 *
 * İlk kurgu `destination = origin` (gidiş-dönüş) idi ve KUSURLUYDU: bir DÖNGÜNÜN iki yönü de
 * toplamda eşdeğerdir, Google hangisini seçeceğine kendi karar verir — gerçek telefondan gelen
 * istekte "en uzaktan başlayıp yakınlarla geri dönen" yönü seçti ve kurye EN UZAK durağı
 * 1. sırada gördü. Gerçek ölçüm (Bursa, 5 durak, aynı origin): döngü kurgusu 27,6 km ve sıra
 * uzağa gidip GERİ DÖNÜYOR; en-uzak-hedef kurgusu 20,0 km ve yakından uzağa akıyor. "En
 * yakından en uzağa" bu özelliğin ürün tanımının kendisi olduğu için hedef, başlangıca kuş
 * uçuşu EN UZAK duraktır — kuş uçuşu yalnız HEDEFİ seçer, aradaki sıra yine Google'ın gerçek
 * yol ağıyla optimize edilir. Dükkân koordinatı şemada yok ve hâlâ UYDURULMAZ.
 *
 * DIŞARIYA ÇIKAN TEK VERİ KOORDİNATTIR (kırmızı çizgi #4'ün en dar yorumu): müşteri adı,
 * telefonu, adres metni, hatta SİPARİŞ KİMLİĞİ bile gövdeye girmez. Sıra, gönderdiğimiz
 * ara durak dizisindeki DİZİN numaralarıyla geri gelir; kimliği bu uçta eşleriz.
 */
final class GoogleRoutesMotoru implements RotaMotoru
{
    /**
     * Google'ın `optimizeWaypointOrder` için ara durak tavanı. Aşıldığında istek HTTP 400 ile
     * reddedilirdi; boşuna gidip para/gecikme yakmak yerine burada durup yakın komşuya düşeriz.
     */
    private const EN_FAZLA_ARA_DURAK = 25;

    public function __construct(
        private readonly string $apiKey,
        private readonly string $baseUrl,
        private readonly int $timeout,
    ) {}

    public function hazirMi(): bool
    {
        return $this->apiKey !== '' && $this->baseUrl !== '';
    }

    public function adi(): string
    {
        return self::GOOGLE;
    }

    /**
     * @param  list<array{id: string, lat: float|null, lng: float|null}>  $duraklar
     * @param  array{lat: float, lng: float}|null  $baslangic
     * @return array{order: list<string>, without_location: int}
     */
    public function sirala(array $duraklar, ?array $baslangic = null): array
    {
        if (! $this->hazirMi()) {
            throw RotaException::yapilandirilmamis();
        }

        /** @var list<array{id: string, lat: float, lng: float}> $konumlu */
        $konumlu = [];
        /** @var list<string> $konumsuz */
        $konumsuz = [];
        foreach ($duraklar as $d) {
            if ($d['lat'] === null || $d['lng'] === null) {
                $konumsuz[] = $d['id'];
            } else {
                $konumlu[] = ['id' => $d['id'], 'lat' => $d['lat'], 'lng' => $d['lng']];
            }
        }

        // Başlangıç verilmediyse listenin ilk durağı origin olur ve sırada BAŞTA kalır
        // (yakın komşunun "ilk durak sabit" davranışıyla aynı sözleşme).
        $originIlkDurak = $baslangic === null;
        $havuz = $originIlkDurak ? array_slice($konumlu, 1) : $konumlu;

        // Tek durak varken "en iyi sıra" tektir; sıfırken zaten sıralanacak şey yoktur.
        if (count($havuz) < 2) {
            return $this->sonuc(array_column($konumlu, 'id'), $konumsuz);
        }

        $origin = $baslangic ?? ['lat' => $konumlu[0]['lat'], 'lng' => $konumlu[0]['lng']];

        // HEDEF = başlangıca kuş uçuşu en uzak durak (sınıf yorumundaki döngü-yönü arızası).
        // Kalanlar ara duraktır; Google onların sırasını gerçek yol ağıyla optimize eder.
        $uzak = $this->enUzakDizin($origin, $havuz);
        $hedef = $havuz[$uzak];
        $ara = array_values(array_filter($havuz, fn (int $k) => $k !== $uzak, ARRAY_FILTER_USE_KEY));

        if (count($ara) > self::EN_FAZLA_ARA_DURAK) {
            // Sayı kişisel veri değildir; koordinat log'a GİRMEZ.
            Log::info('Google Routes atlandi: ara durak tavani asildi', [
                'ara_durak' => count($ara),
                'tavan' => self::EN_FAZLA_ARA_DURAK,
            ]);

            throw RotaException::kapasiteAsildi(count($ara), self::EN_FAZLA_ARA_DURAK);
        }

        $onEk = $originIlkDurak ? [$konumlu[0]['id']] : [];

        // 0-1 ara durakta sıra tek olasılıktır (yakın önce, uzak hedef sona) — Google'a
        // sormak sonucu değiştirmez, yalnız para ve saniye yakar.
        if (count($ara) < 2) {
            return $this->sonuc([...$onEk, ...array_column($ara, 'id'), $hedef['id']], $konumsuz);
        }

        $dizinler = $this->optimalDizinler($origin, $hedef, $ara);

        $sira = $onEk;
        foreach ($dizinler as $dizin) {
            $sira[] = $ara[$dizin]['id'];
        }
        $sira[] = $hedef['id'];

        return $this->sonuc($sira, $konumsuz);
    }

    /**
     * Başlangıca kuş uçuşu EN UZAK durağın dizini. Equirectangular karesel mesafe —
     * RouteOrderer ile aynı yaklaşım: yalnız KARŞILAŞTIRMA için, karekök gereksiz.
     *
     * @param  array{lat: float, lng: float}  $origin
     * @param  non-empty-list<array{id: string, lat: float, lng: float}>  $havuz
     */
    private function enUzakDizin(array $origin, array $havuz): int
    {
        $enUzak = 0;
        $enBuyuk = -1.0;
        foreach ($havuz as $k => $d) {
            $dLat = ($d['lat'] - $origin['lat']) * 111_320.0;
            $dLng = ($d['lng'] - $origin['lng']) * 111_320.0 * cos(deg2rad($origin['lat']));
            $kare = $dLat ** 2 + $dLng ** 2;
            if ($kare > $enBuyuk) {
                $enBuyuk = $kare;
                $enUzak = $k;
            }
        }

        return $enUzak;
    }

    /**
     * Google'a sorar ve ara durakların optimal sırasını DİZİN listesi olarak döner.
     *
     * @param  array{lat: float, lng: float}  $origin
     * @param  array{id: string, lat: float, lng: float}  $hedef
     * @param  list<array{id: string, lat: float, lng: float}>  $araDuraklar
     * @return list<int>
     */
    private function optimalDizinler(array $origin, array $hedef, array $araDuraklar): array
    {
        $nokta = fn (float $lat, float $lng): array => [
            'location' => ['latLng' => ['latitude' => $lat, 'longitude' => $lng]],
        ];

        $govde = [
            'origin' => $nokta($origin['lat'], $origin['lng']),
            // Hedef en uzak duraktır (sınıf yorumu) — destination=origin döngüsü yön belirsizliği
            // yüzünden sahada "en uzak 1. sırada" arızası üretti.
            'destination' => $nokta($hedef['lat'], $hedef['lng']),
            'intermediates' => array_map(
                fn (array $d): array => $nokta($d['lat'], $d['lng']),
                $araDuraklar
            ),
            'travelMode' => 'DRIVE',
            'optimizeWaypointOrder' => true,
        ];

        try {
            $yanit = Http::timeout($this->timeout)
                ->withHeaders([
                    'X-Goog-Api-Key' => $this->apiKey,
                    // Alan maskesi ZORUNLU (Routes API onsuz 400 verir) ve dar tutuldu: rota
                    // geometrisi/süresi bize gerekmiyor, yalnız sıra lazım — küçük yanıt, ucuz katman.
                    'X-Goog-FieldMask' => 'routes.optimizedIntermediateWaypointIndex',
                ])
                ->asJson()
                ->acceptJson()
                ->post($this->baseUrl, $govde);
        } catch (ConnectionException) {
            throw RotaException::ulasilamadi();
        }

        if (! $yanit->successful()) {
            // KVKK: yalnız durum kodu. Yanıt gövdesi ("Billing", anahtar parçası) log'a GİRMEZ.
            Log::warning('Google Routes hata yaniti', ['status' => $yanit->status()]);

            throw RotaException::reddedildi($yanit->status());
        }

        /** @var mixed $cevap */
        $cevap = $yanit->json();

        // Routes API 200 ile de hata dönebilir (`error.status`); `successful()` tek başına yetmez.
        if (data_get($cevap, 'error') !== null) {
            $durum = data_get($cevap, 'error.status');
            Log::warning('Google Routes gövdede hata', ['status' => is_string($durum) ? $durum : 'UNKNOWN']);

            throw RotaException::reddedildi($yanit->status());
        }

        return $this->dizinleriAyristir(data_get($cevap, 'routes.0.optimizedIntermediateWaypointIndex'), count($araDuraklar));
    }

    /**
     * `optimizedIntermediateWaypointIndex` doğrulaması — 0..n-1'in TAM permütasyonu olmalı.
     *
     * NEDEN BU KADAR KATI: eksik ya da tekrarlı bir dizin sessizce durak KAYBETTİRİR ya da
     * ÇOĞALTIR; kurye bir müşteriye hiç uğramaz ve hiçbir şey hata vermez. Bu depodaki en
     * pahalı arıza türü tam olarak budur (kod çalışır, sonuç yalandır). Şüphede istisna atıp
     * yakın komşuya düşmek her zaman daha ucuzdur.
     *
     * @param  mixed  $ham
     * @return list<int>
     */
    private function dizinleriAyristir($ham, int $adet): array
    {
        if (! is_array($ham) || count($ham) !== $adet) {
            throw RotaException::beklenmedikYanit();
        }

        $dizinler = [];
        $gorulen = [];
        /** @var mixed $deger */
        foreach ($ham as $deger) {
            if (! is_int($deger) && ! (is_string($deger) && ctype_digit($deger))) {
                throw RotaException::beklenmedikYanit();
            }

            $dizin = (int) $deger;
            if ($dizin < 0 || $dizin >= $adet || isset($gorulen[$dizin])) {
                throw RotaException::beklenmedikYanit();
            }

            $gorulen[$dizin] = true;
            $dizinler[] = $dizin;
        }

        return $dizinler;
    }

    /**
     * Koordinatsız duraklar SONA — göreli sıraları korunarak. Motor değişse de bu değişmez
     * korunur; UI kaç tanesinin rotaya giremediğini kullanıcıya söyler.
     *
     * @param  list<string>  $sira
     * @param  list<string>  $konumsuz
     * @return array{order: list<string>, without_location: int}
     */
    private function sonuc(array $sira, array $konumsuz): array
    {
        return [
            'order' => [...$sira, ...$konumsuz],
            'without_location' => count($konumsuz),
        ];
    }
}
