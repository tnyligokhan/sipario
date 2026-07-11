<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Cihaz kaydı. id İSTEMCİDE üretilir (uuid:7) ve idempotenttir: aynı device_id ile tekrar
 * çağrı kaydı günceller. tenant_id gövdeden ALINMAZ — oturumdaki kullanıcının tenant'ıdır (RLS zorlar).
 */
class DeviceRegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // auth:sanctum + tenant middleware zaten korur
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'device_id' => ['required', 'uuid:7'],
            'platform' => ['required', 'in:android,ios'],
            'model' => ['nullable', 'string', 'max:120'],
            'os_version' => ['nullable', 'string', 'max:60'],
            'app_version' => ['nullable', 'string', 'max:40'],
            'push_token' => ['nullable', 'string', 'max:255'],
        ];
    }
}
