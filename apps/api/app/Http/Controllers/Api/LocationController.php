<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\LocationHeartbeatRequest;
use App\Models\User;
use App\Support\Konum\CanliKonum;
use App\Support\Konum\KonumDeposu;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;

/**
 * "Canlı kurye konumu" — tasarımdaki harita ekranının sunucu yüzeyi.
 *
 * İKİ UÇ NOKTA, İKİ AYRI YETKİ: kalp atışını HERKES gönderir (patron da sahadadır, operatör de
 * dükkândadır — rol ayrımı yapmak "kim izlenir" kararını sunucuya gömerdi ve rol değişince
 * özellik sessizce bozulurdu), canlı listeyi YALNIZ PATRON okur (`role:patron`, routes/api.php).
 * Kuryenin başka kuryenin nerede olduğunu görmesi için bir iş gerekçesi yok; olmayan yetki
 * sızdırılamaz.
 *
 * KVKK KIRMIZI ÇİZGİSİ (#4): koordinat HİÇBİR log satırına yazılmaz ve dış sağlayıcıya
 * GİTMEZ (geocode/rota uçlarının aksine burada dışarı çıkan tek bayt yoktur). Bu yüzden bu
 * dosyada bilerek Log çağrısı bulunmaz — bir arıza teşhisi için bile eklenmemelidir; log
 * dosyaları yedeklenir, taşınır ve tablonun kendisinden daha uzun yaşar.
 *
 * ÇEVRİMDIŞI: kalp atışı bir KOLAYLIKTIR. Ağ yoksa istemci onu kuyruğa ALMAZ, atar — bayat bir
 * konumu sonradan yollamanın değeri yoktur, zararı vardır (patron kuryeyi olmadığı yerde görür).
 */
class LocationController extends Controller
{
    public function __construct(private readonly KonumDeposu $depo) {}

    /**
     * POST /api/v1/locations/heartbeat
     *
     * 204 döner, gövde YOK: istemcinin geri alacağı bir şey yok ve bu uç nokta saniyede bir
     * çağrılır — dönen her bayt gereksiz mobil veri demektir.
     */
    public function heartbeat(LocationHeartbeatRequest $request): Response
    {
        /** @var User $kullanici */
        $kullanici = $request->user();

        /** @var array{lat: float|int|string, lng: float|int|string, accuracy_m?: float|int|string|null} $girdi */
        $girdi = $request->validated();

        $dogruluk = $girdi['accuracy_m'] ?? null;

        $this->depo->kalpAtisiKaydet(
            $kullanici,
            (float) $girdi['lat'],
            (float) $girdi['lng'],
            $dogruluk === null ? null : (float) $dogruluk,
        );

        return response()->noContent();
    }

    /**
     * GET /api/v1/locations/live — yalnız patron (route'ta `role:patron`, aksi halde 403).
     *
     * Tazelik/pencere kararı depoda verilir; controller filtre uygulamaz. Yanıt `locations`
     * anahtarıyla sarılır (çıplak dizi değil): ileride "sunucu önerilen yenileme aralığı" gibi
     * bir alan eklenirse istemci sözleşmesi kırılmadan büyüyebilsin.
     */
    public function live(): JsonResponse
    {
        return response()->json([
            'locations' => array_map(
                fn (CanliKonum $konum) => $konum->toArray(),
                $this->depo->canliListe(),
            ),
        ]);
    }
}
