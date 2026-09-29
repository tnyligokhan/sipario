<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Yol çizgisi isteği — istemci haritadaki AÇIK siparişlerin kimliklerini GÖRDÜĞÜ SIRAYLA yollar.
 *
 * KOORDİNAT KABUL EDİLMEZ, yalnız sipariş kimliği: koordinatı sunucu kendi RLS'i altında okur.
 * Ham koordinat alan bir uç, herkesin Google'ı bizim hesabımıza bedava çağırabileceği bir
 * aracı olurdu (her çağrı paralı).
 */
class RotaCizgisiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // rota grubu zaten auth:sanctum + tenant middleware'i altında
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // Çizgi en az iki durak ister. Üst sınır bir günlük rotanın çok üstünde; amaç
            // sınırsız gövdeyle maliyet/bellek şişirmeyi engellemek (her 26 durak bir istek).
            'order_ids' => ['required', 'array', 'min:2', 'max:100'],
            'order_ids.*' => ['required', 'uuid', 'distinct'],
        ];
    }
}
