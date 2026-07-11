<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Giriş isteği. Yalnız email+parola (mobilde tenant kodu yok — kırmızı çizgi: sürtünme düşük).
 * İsteğe bağlı `device` bloğu ile aynı çağrıda cihaz kaydı yapılabilir.
 */
class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // public endpoint
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email', 'max:190'],
            'password' => ['required', 'string'],

            'device' => ['sometimes', 'array'],
            'device.device_id' => ['required_with:device', 'uuid:7'],
            'device.platform' => ['required_with:device', 'in:android,ios'],
            'device.model' => ['nullable', 'string', 'max:120'],
            'device.os_version' => ['nullable', 'string', 'max:60'],
            'device.app_version' => ['nullable', 'string', 'max:40'],
            'device.push_token' => ['nullable', 'string', 'max:255'],
        ];
    }
}
