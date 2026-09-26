<?php

namespace App\Http\Controllers\Api;

use App\Harita\KaroAracisi;
use App\Http\Controllers\Controller;
use Illuminate\Http\Response;

/**
 * Harita karosu — `GET /api/v1/harita/karo/{stil}/{z}/{x}/{dosya}` (dosya: "1601.png" | "1601@2x.png").
 *
 * Kiracıya ait veri TAŞIMAZ (kamuya açık harita görseli). Oturum istemesinin tek sebebi CARTO
 * kotamızı yabancılardan korumaktır: açık bir aracı herkesin bedava karo sunucusu olurdu.
 */
class HaritaController extends Controller
{
    public function karo(string $stil, int $z, int $x, string $dosya): Response
    {
        abort_unless(in_array($stil, KaroAracisi::STILLER, true), 404);
        abort_unless(preg_match('/^(\d+)(@2x)?\.png$/', $dosya, $m) === 1, 404);
        $y = (int) $m[1];
        $retina = ($m[2] ?? '') !== '';

        // Karo ızgarası sınırı: z seviyesinde 2^z karo vardır. Sınır dışı istek CARTO'ya hiç gitmez.
        $kenar = 1 << min(max($z, 0), 20);
        abort_unless($z >= 0 && $z <= 20 && $x < $kenar && $y < $kenar, 404);

        $baytlar = KaroAracisi::yapilandirmadan()->karo($stil, $z, $x, $y, $retina);
        if ($baytlar === null) {
            // Uygulama karo hatasını SESSİZ geçer (gri karo, pinler durur); 503 log'da görünür.
            return response('', 503);
        }

        return response($baytlar, 200, [
            'Content-Type' => 'image/png',
            // Cihaz aynı karoyu bir hafta boyunca yeniden istemesin.
            'Cache-Control' => 'private, max-age=604800',
        ]);
    }
}
