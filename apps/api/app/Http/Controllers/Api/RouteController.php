<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AutoRouteRequest;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Route\RouteOrderer;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

/**
 * "Oto Sırala (rota)" — tasarım `s-siparisler.jsx` sıralama sayfasındaki kontörlü eylem.
 *
 * NEDEN AYRI BİR UÇ NOKTA (senkron push'un içinde değil):
 *  - Kontör SUNUCU SAHİPLİDİR. İstemci `route_credits`i yazamaz (abonelik gibi); düşme
 *    yetkisi sunucuda kalmalı, yoksa çevrimdışı bir istemci sınırsız hak üretirdi.
 *  - Sonuç bir SIRA ÖNERİSİDİR, kayıt değil. Sipariş satırlarına yazma yine tek yazma
 *    yüzeyinden (sync push → `sort_set` olayı) geçer; offline-first ve LWW semantiği bozulmaz.
 *    Yani bu uç nokta orders tablosuna DOKUNMAZ.
 *
 * KONTÖR YOKSA 409: kullanıcı bir şey kaybetmez, mevcut sıra korunur ve istemci nötr bir
 * mesaj gösterir. Mağaza kuralı gereği mesajda satın alma/fiyat/yükseltme çağrısı YOKTUR.
 */
class RouteController extends Controller
{
    /** POST /api/v1/orders/auto-route */
    public function autoRoute(AutoRouteRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        /** @var list<string> $istenen */
        $istenen = $request->validated()['order_ids'];

        // Kontör düşümü ile sıra hesabı AYNI transaction'da: hak düşüp sıra dönmemesi ya da
        // sıra dönüp hak düşmemesi mümkün olmasın. `tenant` middleware'i isteği zaten bir
        // transaction'a sarıyor; satır kilidi (FOR UPDATE) eşzamanlı iki cihazın aynı hakkı
        // iki kez harcamasını engeller.
        $tenant = Tenant::query()->lockForUpdate()->find($user->tenant_id);
        abort_if($tenant === null, 409, 'Hesabınızın kiracı bağlamı bulunamadı, destek alın.');

        if ($tenant->route_credits <= 0) {
            return response()->json([
                'message' => 'Oto sıralama hakkınız kalmadı.',
                'route_credits' => 0,
            ], 409);
        }

        $duraklar = $this->duraklar($istenen);
        if ($duraklar === []) {
            // Sıralanacak hiçbir geçerli sipariş yok — HAK DÜŞÜRÜLMEZ. Boş bir işlem için
            // kontör yakmak kullanıcıya haksızlık olurdu.
            return response()->json([
                'message' => 'Sıralanacak sipariş bulunamadı.',
                'route_credits' => $tenant->route_credits,
            ], 422);
        }

        $sonuc = RouteOrderer::sirala($duraklar);

        $tenant->decrement('route_credits');

        return response()->json([
            'order' => $sonuc['order'],
            'without_location' => $sonuc['without_location'],
            'route_credits' => $tenant->route_credits,
        ]);
    }

    /**
     * İstenen siparişlerin durak noktaları. RLS altında sorgulanır: başka bayinin kimliği
     * listeye konsa sıfır satır döner ve sıralamaya hiç girmez.
     *
     * Konum müşterinin BİRİNCİL adresinden gelir; adresi ya da koordinatı olmayan sipariş
     * `lat/lng = null` ile döner (RouteOrderer onları sona atar). İstemcinin gönderdiği SIRA
     * korunur — en yakın komşu zinciri ilk duraktan başlar, o da bu sıradaki ilk siparştir.
     *
     * @param  list<string>  $istenen
     * @return list<array{id: string, lat: float|null, lng: float|null}>
     */
    private function duraklar(array $istenen): array
    {
        $satirlar = DB::table('orders as o')
            ->leftJoin('customer_addresses as a', function ($join) {
                $join->on('a.customer_id', '=', 'o.customer_id')
                    ->where('a.is_primary', '=', true)
                    ->whereNull('a.deleted_at');
            })
            ->whereIn('o.id', $istenen)
            ->whereNull('o.deleted_at')
            ->where('o.status', '=', 'open')
            ->select('o.id', 'a.lat', 'a.lng')
            ->get()
            ->keyBy('id');

        $duraklar = [];
        foreach ($istenen as $id) {
            $satir = $satirlar->get($id);
            if ($satir === null) {
                continue; // başka bayinin / silinmiş / kapanmış sipariş
            }
            $duraklar[] = [
                'id' => $id,
                'lat' => $satir->lat === null ? null : (float) $satir->lat,
                'lng' => $satir->lng === null ? null : (float) $satir->lng,
            ];
        }

        return $duraklar;
    }
}
