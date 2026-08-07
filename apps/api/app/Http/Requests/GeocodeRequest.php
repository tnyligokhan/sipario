<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Adres → koordinat isteği. İstemci YALNIZ serbest adres metni (+ opsiyonel bölge) yollar.
 *
 * KVKK (kırmızı çizgi #4): bu uç noktaya müşteri adı, telefonu ya da kimliği KABUL EDİLMEZ —
 * alan listesi bilerek iki alandır. Dışarıya (Yandex/Google) çıkan tek veri adres metnidir;
 * kişiyi tanımlayan hiçbir alan sınırı geçmez. Gövdeye fazladan alan konursa doğrulama onu
 * yok sayar, sağlayıcıya taşınacak bir yol yoktur.
 */
class GeocodeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // grup zaten auth:sanctum + tenant middleware'i altında
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // 3 karakterin altı anlamlı arama değildir; her tuş vuruşunda kota yakmayı da engeller.
            'query' => ['required', 'string', 'min:3', 'max:200'],
            'region' => ['nullable', 'string', 'max:100'],
        ];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'query.required' => 'Aranacak adres metni gerekli.',
            'query.min' => 'Adres en az 3 karakter olmalı.',
        ];
    }
}
