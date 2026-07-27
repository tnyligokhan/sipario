<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Giriş isteği — tasarım `s-giris.jsx`: **firma kodu + kullanıcı adı + parola**.
 *
 * ÖNCEKİ KARAR GEÇERSİZ: burada eskiden "yalnız email+parola (mobilde tenant kodu yok —
 * sürtünme düşük)" yazıyordu. SİPARİO 3.0 tasarımı bunu bilinçle geri aldı: bayinin
 * kuryesi/tezgâhtarı çoğu zaman e-posta sahibi değildir, hesabını patron açar. Firma kodu
 * tasarımda İşletme Profili ekranında ayrı bir kart olarak yayınlanıyor ("Kullanıcılarınız
 * bu kodla giriş yapar; değiştirilemez"), yani bir sürtünme değil, kurulumun parçası.
 *
 * Kurallar tasarımın kendi doğrulamalarıyla birebir:
 *   firma kodu    ^[a-z0-9-]{3,}$
 *   kullanıcı adı ^[a-z0-9._-]{3,}$
 *   parola        en az 4 karakter
 *
 * İsteğe bağlı `device` bloğu ile aynı çağrıda cihaz kaydı yapılabilir.
 */
class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // public endpoint
    }

    /**
     * Büyük/küçük harf giriş engeli olmasın: "MerkezBayi" yazan da girebilsin.
     * Karşılaştırma her katmanda küçük harf üzerinden yapılır (DB fonksiyonunda da lower()).
     */
    protected function prepareForValidation(): void
    {
        foreach (['tenant_code', 'username'] as $alan) {
            $deger = $this->input($alan);
            if (is_string($deger)) {
                $this->merge([$alan => strtolower(trim($deger))]);
            }
        }
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'tenant_code' => ['required', 'string', 'max:60', 'regex:/^[a-z0-9-]{3,}$/'],
            'username' => ['required', 'string', 'max:60', 'regex:/^[a-z0-9._-]{3,}$/'],
            'password' => ['required', 'string', 'min:4'],

            'device' => ['sometimes', 'array'],
            'device.device_id' => ['required_with:device', 'uuid:7'],
            'device.platform' => ['required_with:device', 'in:android,ios'],
            'device.model' => ['nullable', 'string', 'max:120'],
            'device.os_version' => ['nullable', 'string', 'max:60'],
            'device.app_version' => ['nullable', 'string', 'max:40'],
            'device.push_token' => ['nullable', 'string', 'max:255'],
        ];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'tenant_code.required' => 'Firma kodu boş bırakılamaz',
            'tenant_code.regex' => 'Geçersiz firma kodu (en az 3 harf/rakam)',
            'username.required' => 'Kullanıcı adı boş bırakılamaz',
            'username.regex' => 'Geçersiz kullanıcı adı (en az 3 harf/rakam)',
            'password.required' => 'Parola boş bırakılamaz',
            'password.min' => 'Parola en az 4 karakter',
        ];
    }
}
