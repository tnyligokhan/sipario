<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\GeocodeRequest;
use App\Support\Geocoding\Geocoder;
use App\Support\Geocoding\GeocodingException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;

/**
 * "Adresten Konum Al" — serbest adres metnini ADAY koordinatlara çevirir.
 *
 * NEDEN SUNUCUDA (istemci doğrudan Yandex'e gitmiyor):
 *  1. Anahtar. APK'ya gömülen anahtar ilk kurulumda çıkarılır ve kotamız yakılır.
 *  2. Önbellek. Aynı mahalle onlarca müşteride tekrar eder; ikinci sorgu bedavaya gelmeli.
 *  3. Sağlayıcı bağımsızlığı. Yandex→Google geçişi bir env satırıdır, uygulama güncellemesi değil.
 *
 * KONUM OTOMATİK ATANMAZ: burası birden çok aday döner, doğrusunu KULLANICI seçer. Yanlış
 * algılanan bir adres yüzünden kuryenin yanlış kapıya gitmesi, listeden seçim yapmaktan pahalıdır.
 *
 * ÇEVRİMDIŞI: bu çevrimİÇİ bir kolaylıktır. Ağ yoksa müşteri konumsuz kaydedilir ve kayıt akışı
 * HİÇ engellenmez (kırmızı çizgi #3) — konum sonradan eklenir.
 */
class GeocodeController extends Controller
{
    public function __construct(private readonly Geocoder $geocoder) {}

    /** POST /api/v1/geocode */
    public function search(GeocodeRequest $request): JsonResponse
    {
        /** @var array{query: string, region?: string|null} $girdi */
        $girdi = $request->validated();

        $sorgu = $this->sorguKur($girdi['query'], $girdi['region'] ?? null);
        $enFazla = max(1, (int) config('geocoding.max_results', 5));

        try {
            $adaylar = $this->onbellekli($sorgu, $enFazla);
        } catch (GeocodingException $e) {
            // 503: geçici servis arızası. Mesaj NÖTR ve eylem önerir; ham sağlayıcı hatası
            // (anahtar/kota) burada değil log'da durur.
            return response()->json(['message' => $e->getMessage(), 'results' => []], 503);
        }

        return response()->json(['results' => $adaylar]);
    }

    /**
     * Sağlayıcıya gidecek tek metni kurar: adres + (varsa) bölge.
     *
     * Şehir UYDURULMAZ. Bayinin ili şemada yoktur; "Antalya" eklemek pilot dışındaki ilk bayide
     * her adresi 500 km öteye taşırdı. Bölge ipucu kullanıcının kendi yazdığıdır, tahmin değil.
     */
    private function sorguKur(string $adres, ?string $bolge): string
    {
        $adres = trim(preg_replace('/\s+/u', ' ', $adres) ?? $adres);
        $bolge = $bolge === null ? '' : trim(preg_replace('/\s+/u', ' ', $bolge) ?? $bolge);

        if ($bolge === '') {
            return $adres;
        }

        // Bölge zaten adres metninin içinde geçiyorsa tekrarlamayız — "Kepez, Kepez" sağlayıcının
        // eşleşme skorunu düşürür.
        if (mb_stripos($adres, $bolge) !== false) {
            return $adres;
        }

        return $adres.', '.$bolge;
    }

    /**
     * Aynı adres iki kez sorulmaz.
     *
     * Önbellek KİRACIDAN BAĞIMSIZ (global): dönen şey kamuya açık coğrafi veridir, kiracıya ait
     * hiçbir bilgi taşımaz — bu yüzden RLS'e tabi bir tabloda değil, sıradan önbellekte durur ve
     * bir bayinin sorduğu mahalle diğerine bedavaya gelir. Anahtar sağlayıcıyı İÇERİR: Yandex
     * ile Google'ın adayları farklıdır, sürücü değişince bayat sonuç dönmemelidir.
     *
     * Boş sonuç da önbelleklenir: bulunamayan adres tekrar tekrar sorulup kota yakmasın.
     * Arıza önbelleklenmez — istisna `remember`ı yarıda keser, bir sonraki deneme gerçekten gider.
     *
     * @return list<array{text: string, lat: float, lng: float, precision: string, source: string}>
     */
    private function onbellekli(string $sorgu, int $enFazla): array
    {
        $surucu = (string) config('geocoding.driver', 'null');
        $anahtar = 'geo:'.$surucu.':'.$enFazla.':'.sha1(mb_strtolower($sorgu, 'UTF-8'));
        $gun = max(1, (int) config('geocoding.cache_days', 30));

        /** @var list<array{text: string, lat: float, lng: float, precision: string, source: string}> */
        return Cache::remember(
            $anahtar,
            now()->addDays($gun),
            fn () => array_map(
                fn ($aday) => $aday->toArray(),
                $this->geocoder->ara($sorgu, $enFazla)
            )
        );
    }
}
