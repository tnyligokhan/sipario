<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AutoRouteRequest;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Route\RotaException;
use App\Support\Route\RotaMotoru;
use App\Support\Route\YakinKomsuMotoru;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

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
    /**
     * POST /api/v1/orders/auto-route
     *
     * ADIM SIRASI TESADÜF DEĞİL — her adımın gerekçesi var:
     *  1. Duraklar: geçerli sipariş yoksa 422 ve kontör YANMAZ (boş işlem hak harcamaz).
     *  2. Kontöre KİLİTSİZ ön bakış: sıfırsa erken 409. Hakkı olmayan bir isteğe paralı dış
     *     servisi çalıştırmak parayı çöpe atmak olurdu.
     *  3. Sıralama (gerekirse dış HTTP). Motor arızalanırsa yakın komşuya düşülür.
     *  4. SONRA kilit + koşullu düşüm. Kritik: HTTP çağrısı satır kilidinin DIŞINDA kalmalı —
     *     8 saniyelik bir dış istek boyunca `tenants` satırını kilitli tutmak, aynı bayinin
     *     tüm eşzamanlı isteklerini o süre boyunca sıraya dizerdi.
     */
    public function autoRoute(AutoRouteRequest $request, RotaMotoru $motor): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        /** @var array<string, mixed> $dogrulanmis */
        $dogrulanmis = $request->validated();
        /** @var list<string> $istenen */
        $istenen = $dogrulanmis['order_ids'];

        $tenant = Tenant::query()->find($user->tenant_id);
        abort_if($tenant === null, 409, 'Hesabınızın kiracı bağlamı bulunamadı, destek alın.');

        $duraklar = $this->duraklar($istenen);
        if ($duraklar === []) {
            // Sıralanacak hiçbir geçerli sipariş yok — HAK DÜŞÜRÜLMEZ. Boş bir işlem için
            // kontör yakmak kullanıcıya haksızlık olurdu.
            return response()->json([
                'message' => 'Sıralanacak sipariş bulunamadı.',
                'route_credits' => $tenant->route_credits,
            ], 422);
        }

        if ($tenant->route_credits <= 0) {
            return response()->json([
                'message' => 'Oto sıralama hakkınız kalmadı.',
                'route_credits' => 0,
            ], 409);
        }

        [$sonuc, $engine] = $this->siralamayiKos($motor, $duraklar, $this->baslangic($dogrulanmis));

        // Satır kilidi (FOR UPDATE) eşzamanlı iki cihazın aynı hakkı iki kez harcamasını
        // engeller: kilidi kazanan düşürür, ikincisi taze değeri okur. Ön bakıştan bu ana kadar
        // hak tükendiyse 409 — kontör EKSİYE DÜŞMEZ. (`tenant` middleware'i isteği zaten tek bir
        // transaction'a sarıyor; kilit bu yüzden istek sonuna dek yaşar, o yüzden EN SONA konur.)
        $kilitli = Tenant::query()->lockForUpdate()->find($user->tenant_id);
        if ($kilitli === null || $kilitli->route_credits <= 0) {
            return response()->json([
                'message' => 'Oto sıralama hakkınız kalmadı.',
                'route_credits' => 0,
            ], 409);
        }

        // Kontör MOTOR FARK ETMEKSİZİN 1 düşer: ürün kuralı "1 sıralama = 1 kontör". Google'a
        // düşüp yakın komşuya geri dönmüş olmak kullanıcının sorunu değildir; ikinci kez de yanmaz.
        $kilitli->decrement('route_credits');

        return response()->json([
            'order' => $sonuc['order'],
            'without_location' => $sonuc['without_location'],
            'route_credits' => $kilitli->route_credits,
            'engine' => $engine,
        ]);
    }

    /**
     * Yapılandırılmış motoru koşar; ARIZADA yakın komşuya düşer.
     *
     * Bu özellik ASLA 5xx vermez: yakın komşu saftır (ağ, anahtar, kota yok), her koşulda bir
     * sıra üretir. Dış servisin ölmesi kullanıcının işini durdurmaz — sıra yalnız biraz daha
     * kaba olur ve sebep log'a düşer (kullanıcıya "Billing"/"API key" gibi bir ayrıntı SIZMAZ).
     *
     * @param  list<array{id: string, lat: float|null, lng: float|null}>  $duraklar
     * @param  array{lat: float, lng: float}|null  $baslangic
     * @return array{0: array{order: list<string>, without_location: int}, 1: string}
     */
    private function siralamayiKos(RotaMotoru $motor, array $duraklar, ?array $baslangic): array
    {
        try {
            return [$motor->sirala($duraklar, $baslangic), $motor->adi()];
        } catch (RotaException $e) {
            Log::warning('Rota motoru dustu, yakin komsuya dusuldu', [
                'motor' => $motor->adi(),
                'sebep' => $e->getMessage(),
            ]);

            $yedek = new YakinKomsuMotoru;

            return [$yedek->sirala($duraklar, $baslangic), $yedek->adi()];
        }
    }

    /**
     * Cihazın anlık konumu. Doğrulama zaten aralığı sınadı; burada yalnız "iki alan da var mı"
     * kontrolü kalır — `start` hiç gelmediğinde ya da `null` geldiğinde başlangıç UYDURULMAZ,
     * motor eski davranışa (ilk durak sabit) döner.
     *
     * @param  array<string, mixed>  $dogrulanmis
     * @return array{lat: float, lng: float}|null
     */
    private function baslangic(array $dogrulanmis): ?array
    {
        /** @var mixed $ham */
        $ham = $dogrulanmis['start'] ?? null;
        if (! is_array($ham) || ! isset($ham['lat'], $ham['lng'])) {
            return null;
        }

        /** @var mixed $lat */
        $lat = $ham['lat'];
        /** @var mixed $lng */
        $lng = $ham['lng'];
        if (! is_numeric($lat) || ! is_numeric($lng)) {
            return null;
        }

        return ['lat' => (float) $lat, 'lng' => (float) $lng];
    }

    /**
     * İstenen siparişlerin durak noktaları. RLS altında sorgulanır: başka bayinin kimliği
     * listeye konsa sıfır satır döner ve sıralamaya hiç girmez.
     *
     * Konum müşterinin BİRİNCİL adresinden gelir; adresi ya da koordinatı olmayan sipariş
     * `lat/lng = null` ile döner (motorlar onları sona atar). İstemcinin gönderdiği SIRA korunur:
     * `start` gelmediğinde zincir bu sıradaki ilk siparişten başlar.
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
