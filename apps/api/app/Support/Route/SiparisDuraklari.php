<?php

namespace App\Support\Route;

use Illuminate\Support\Facades\DB;

/**
 * İstenen AÇIK siparişlerin durak noktaları — "Oto Sırala" ve "yol çizgisi" uçlarının ORTAK okuması.
 *
 * Tek yerde durur ki iki uç aynı siparişi farklı noktada görmesin (sıralanan durak ile çizilen
 * durak ayrışırsa kurye çizginin var olmayan bir kapıya gittiğini görürdü).
 *
 * RLS altında sorgulanır: başka bayinin kimliği listeye konsa sıfır satır döner ve hiç girmez.
 * Konum müşterinin BİRİNCİL adresinden gelir; adresi ya da koordinatı olmayan sipariş
 * `lat/lng = null` ile döner. İstemcinin gönderdiği SIRA korunur.
 */
final class SiparisDuraklari
{
    /**
     * @param  list<string>  $istenen
     * @return list<array{id: string, lat: float|null, lng: float|null}>
     */
    public static function oku(array $istenen): array
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
