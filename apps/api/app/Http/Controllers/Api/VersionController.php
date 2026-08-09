<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/**
 * GET /api/v1/version — sunucu sözleşmesinin sürümü. PUBLIC (kimliksiz), bilinçli.
 *
 * NEDEN AYRI BİR UÇ NOKTA VAR (AppendServerMeta zaten her yanıta `api_version` koyuyorken):
 * o alan ancak BİR İSTEK YAPILABİLDİĞİNDE görünür ve diğer uçların hepsi ya token ister ya
 * kimlik bilgisi. "Canlıda hangi sürüm koşuyor?" sorusunu soran taraf çoğu zaman elinde token
 * OLMAYAN taraftır: durum çubuğu, dağıtım sonrası doğrulama, bir saha arızasında "sunucu mu
 * eski, telefon mu" ayrımı. Girişe garip veri POST'layıp 401 gövdesinden sürüm okumak bunun
 * yerine geçmez — hız sınırını yakar ve niyeti gizler.
 *
 * NEDEN KİMLİK İSTEMİYOR: dönen tek şey KENDİ sözleşmemizin numarasıdır; PHP/Laravel sürümü,
 * ortam ya da yapılandırma sızmaz. Kiracıya ait hiçbir veriye dokunmaz, veritabanına gitmez.
 * `throttle:api` (IP başına 60/dk) genel DoS payını sınırlar.
 *
 * `server_time` alanını AppendServerMeta ekler — burada tekrarlanmaz.
 */
class VersionController extends Controller
{
    public function show(): JsonResponse
    {
        return response()->json([
            'api_version' => (string) config('app.version'),
        ]);
    }
}
