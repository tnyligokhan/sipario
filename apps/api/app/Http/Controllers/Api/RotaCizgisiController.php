<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\RotaCizgisiRequest;
use App\Models\User;
use App\Support\Route\GoogleYolCizgisi;
use App\Support\Route\RotaException;
use App\Support\Route\SiparisDuraklari;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * POST /api/v1/rota/cizgi — haritadaki durakları gerçek yollardan bağlayan çizgi (2026-09-29).
 *
 * KONTÖR DÜŞMEZ: bu bir sıralama değil, çizimdir. Maliyeti iki şey sınırlar: aynı durak dizisi
 * için sonuç ÖNBELLEKTEN gelir (kiracı başına, `rota.cizgi_onbellek_gun`) ve `throttle:rota-cizgi`.
 * Önbelleğe yalnız BAŞARILI sonuç girer — bir arıza günlerce düz çizgi gösterdirmesin.
 *
 * ASLA 5xx YIKMAZ ama DÜRÜSTTÜR: servis yoksa ya da düştüyse 503 + gerekçe döner; istemci bunu
 * sessizce karşılar ve kuş uçuşu kesikli çizgiye düşer (harita hiçbir koşulda kırılmaz).
 *
 * Yanıttaki `duraklar`, çizginin DAYANDIĞI koordinatlardır: telefondaki pin henüz senkronlanmamış
 * bir konumdaysa istemci farkı görür ve yanlış kapıya giden bir yol çizmek yerine düz çizgiye düşer.
 */
class RotaCizgisiController extends Controller
{
    public function ciz(RotaCizgisiRequest $request, GoogleYolCizgisi $cizici): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        /** @var list<string> $istenen */
        $istenen = $request->validated()['order_ids'];

        $noktalar = [];
        foreach (SiparisDuraklari::oku($istenen) as $d) {
            if ($d['lat'] !== null && $d['lng'] !== null) {
                $noktalar[] = ['lat' => $d['lat'], 'lng' => $d['lng']];
            }
        }

        $duraklar = array_map(fn (array $n): array => [$n['lat'], $n['lng']], $noktalar);
        if (count($noktalar) < 2) {
            return response()->json(['noktalar' => [], 'duraklar' => $duraklar]);
        }

        if (! $cizici->hazirMi()) {
            return response()->json(['message' => 'Yol çizgisi bu kurulumda tanımlı değil.'], 503);
        }

        $anahtar = sprintf('rota-cizgi:%s:%s', $user->tenant_id, sha1(json_encode($duraklar) ?: ''));

        /** @var mixed $cizgi */
        $cizgi = Cache::get($anahtar);
        if (! is_array($cizgi)) {
            try {
                $cizgi = $cizici->ciz($noktalar);
            } catch (RotaException $e) {
                Log::warning('Yol cizgisi alinamadi', ['sebep' => $e->getMessage()]);

                return response()->json(['message' => 'Yol çizgisi şu an alınamıyor.'], 503);
            }
            $gun = max(1, (int) config('rota.cizgi_onbellek_gun', 7));
            Cache::put($anahtar, $cizgi, now()->addDays($gun));
        }

        return response()->json(['noktalar' => $cizgi, 'duraklar' => $duraklar]);
    }
}
