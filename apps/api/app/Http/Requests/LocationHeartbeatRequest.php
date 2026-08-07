<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Konum kalp atışı gövdesi. İstemci YALNIZ üç alan yollar: enlem, boylam, (opsiyonel) hata payı.
 *
 * ALAN LİSTESİ BİLEREK BU KADAR DAR (KVKK, kırmızı çizgi #4):
 *  - `user_id` YOK — kim olduğu token'dan çözülür; gövdeden alınsaydı bir kullanıcı başkasının
 *    adına konum bildirebilirdi.
 *  - `reported_at` YOK — damgayı sunucu koyar; istemci zaman gönderebilseydi tazelik kuralı
 *    (ve dolayısıyla gizlilik penceresi) istemci tarafından esnetilebilirdi.
 *  - hız/yön/rakım/pil gibi hiçbir ek telemetri YOK — özelliğin sorusu "şu an neredeler",
 *    toplanmayan alan sızdırılamaz.
 */
class LocationHeartbeatRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // grup zaten auth:sanctum + tenant middleware'i altında
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // Aralık kontrolü DB'de de var (migration 901 CHECK): bozuk bir GPS okuması ya da
            // kasıtlı bir değer haritayı dünyanın dışına atmaz.
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
            // Negatif hata payı anlamsızdır; null = cihaz doğruluğu bilmiyor (meşru durum).
            'accuracy_m' => ['nullable', 'numeric', 'min:0'],
        ];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'lat.required' => 'Enlem gerekli.',
            'lat.between' => 'Enlem -90 ile 90 arasında olmalı.',
            'lng.required' => 'Boylam gerekli.',
            'lng.between' => 'Boylam -180 ile 180 arasında olmalı.',
        ];
    }
}
