<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * "Oto Sırala (rota)" isteği — istemci sıralanacak AÇIK siparişlerin kimliklerini gönderir.
 *
 * Neden istemci gönderiyor: hangi siparişlerin ekranda olduğunu (kurye filtresi, "Açık"
 * sekmesi, o günün kapsamı) istemci bilir. Sunucu yine de kendi RLS'i altında doğrular —
 * başka bayinin siparişi listeye konsa sessizce düşer, sıralamaya girmez.
 *
 * `start` OPSİYONELDİR ve öyle kalmalı: konum izni reddedilmiş, GPS kapalı ya da eski sürüm
 * bir istemci bu alanı gönderemez. Yoksa sıralama eski davranışla (ilk durak sabit) yapılır;
 * özellik konum yüzünden ASLA kapanmaz.
 */
class AutoRouteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // rota grubu zaten auth:sanctum + tenant middleware'i altında
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // Üst sınır bir bayinin bir günde makul olarak taşıyabileceğinin çok üstünde;
            // amaç sınırsız gövdeyle bellek şişirmeyi engellemek.
            'order_ids' => ['required', 'array', 'min:1', 'max:500'],
            // `distinct`: aynı kimlik iki kez gelirse durak ÇOĞALIRDI — RotaMotoru sözleşmesi
            // "hiçbir durak kaybolmaz, çoğalmaz" der; sözleşmeyi kapıda korumak motorlarda
            // tek tek savunmaktan ucuzdur (inceleme bulgusu 2026-07-29).
            'order_ids.*' => ['required', 'uuid', 'distinct'],

            // Cihazın anlık konumu. `array:lat,lng` fazladan alanı REDDEDER — bu uç noktadan
            // dışarıya (Google) koordinat çıkıyor; gövdeye ne girdiği sıkı tutulmalı.
            // `nullable`: istemci konumu alamadığında alanı `null` yollayabilir, bu hata değildir.
            'start' => ['sometimes', 'nullable', 'array:lat,lng'],
            // Yarım koordinat yoktur: biri varsa ikisi de zorunlu. Aralık dışı değer 422'dir —
            // sessizce kırpılsa kurye şehrin dışından başlayan bir sıra görürdü.
            'start.lat' => ['required_with:start', 'numeric', 'between:-90,90'],
            'start.lng' => ['required_with:start', 'numeric', 'between:-180,180'],
        ];
    }
}
