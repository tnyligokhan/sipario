<?php

namespace App\Support\Route;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Durakları VERİLEN SIRAYLA gerçek yollardan bağlayan çizgi — Google Routes `computeRoutes`
 * (kullanıcı isteği 2026-09-29: "konumlar arası yolu kuşbakışı çiziyor, yollardan çizmeli").
 *
 * SIRALAMA YAPMAZ (`optimizeWaypointOrder` YOK): sıra istemcinin sırasıdır — oto sıralamanın
 * sonucu ya da elle dizilmiş sıra. Bu uç yalnız "bu sırayla gidilirse yol nereden geçer" der.
 *
 * UCUZ TUTULUR: alan maskesi yalnız `routes.polyline.encodedPolyline`, kalite `OVERVIEW` (harita
 * ölçeğinde yeterli, yanıt küçük). Trafik istenmez. Aynı sıra için sonuç çağıran tarafta
 * önbelleğe alınır (bkz. `RotaCizgisiController`).
 *
 * DIŞARIYA ÇIKAN TEK VERİ KOORDİNATTIR — `GoogleRoutesMotoru` ile aynı kural (kırmızı çizgi #4).
 */
final class GoogleYolCizgisi
{
    /** Tek istekte ara durak tavanı (Routes API sınırı). Başlangıç + 25 + hedef = 27 nokta. */
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

    /**
     * @param  list<array{lat: float, lng: float}>  $noktalar  Sırasıyla, en az 2.
     * @return list<array{0: float, 1: float}>
     *
     * @throws RotaException
     */
    public function ciz(array $noktalar): array
    {
        if (! $this->hazirMi()) {
            throw RotaException::yapilandirilmamis();
        }
        if (count($noktalar) < 2) {
            return [];
        }

        // Uzun rota PARÇALANIR: her parça bir öncekinin son noktasından başlar ki çizgi kopmasın.
        $parcaBoyu = self::EN_FAZLA_ARA_DURAK + 2;
        $cizgi = [];
        for ($bas = 0; $bas < count($noktalar) - 1; $bas += $parcaBoyu - 1) {
            $parca = array_slice($noktalar, $bas, $parcaBoyu);
            $yol = $this->parcaCiz($parca);
            // Parçaların birleşim noktası iki kez gelmesin.
            if ($cizgi !== [] && $yol !== []) {
                array_shift($yol);
            }
            array_push($cizgi, ...$yol);
        }

        return $cizgi;
    }

    /**
     * @param  list<array{lat: float, lng: float}>  $parca  2..27 nokta
     * @return list<array{0: float, 1: float}>
     */
    private function parcaCiz(array $parca): array
    {
        $nokta = fn (array $n): array => [
            'location' => ['latLng' => ['latitude' => $n['lat'], 'longitude' => $n['lng']]],
        ];

        $govde = [
            'origin' => $nokta($parca[0]),
            'destination' => $nokta($parca[count($parca) - 1]),
            'intermediates' => array_map($nokta, array_slice($parca, 1, -1)),
            'travelMode' => 'DRIVE',
            'polylineQuality' => 'OVERVIEW',
        ];

        try {
            $yanit = Http::timeout($this->timeout)
                ->withHeaders([
                    'X-Goog-Api-Key' => $this->apiKey,
                    'X-Goog-FieldMask' => 'routes.polyline.encodedPolyline',
                ])
                ->asJson()
                ->acceptJson()
                ->post($this->baseUrl, $govde);
        } catch (ConnectionException) {
            throw RotaException::ulasilamadi();
        }

        if (! $yanit->successful()) {
            // KVKK: yalnız durum kodu. Yanıt gövdesi log'a GİRMEZ.
            Log::warning('Google yol cizgisi hata yaniti', ['status' => $yanit->status()]);

            throw RotaException::reddedildi($yanit->status());
        }

        /** @var mixed $kodlu */
        $kodlu = data_get($yanit->json(), 'routes.0.polyline.encodedPolyline');
        if (! is_string($kodlu) || $kodlu === '') {
            throw RotaException::beklenmedikYanit();
        }

        return PolylineCozucu::coz($kodlu);
    }
}
