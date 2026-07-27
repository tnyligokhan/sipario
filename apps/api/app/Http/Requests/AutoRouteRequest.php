<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * "Oto Sırala (rota)" isteği — istemci sıralanacak AÇIK siparişlerin kimliklerini gönderir.
 *
 * Neden istemci gönderiyor: hangi siparişlerin ekranda olduğunu (kurye filtresi, "Açık"
 * sekmesi, o günün kapsamı) istemci bilir. Sunucu yine de kendi RLS'i altında doğrular —
 * başka bayinin siparişi listeye konsa sessizce düşer, sıralamaya girmez.
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
            'order_ids.*' => ['required', 'uuid'],
        ];
    }
}
