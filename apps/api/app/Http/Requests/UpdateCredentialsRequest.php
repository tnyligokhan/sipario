<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * Ekip üyesinin GİRİŞ BİLGİLERİ (kullanıcı adı / parola) — kullanıcı isteği 2026-08-04.
 *
 * Kurallar veritabanındaki kısıtların AYNISIDIR (migration 000701): kullanıcı adı
 * `^[a-z0-9._-]{3,60}$` ve bayi içinde tekil. İkisini burada da yazmak kopya değil, KAPI:
 * CHECK ihlali kullanıcıya 500 gibi görünürdü, oysa bu bir form hatasıdır ve alan adıyla
 * söylenmelidir.
 *
 * Parola alt sınırı 4: mevcut giriş doğrulamasıyla (LoginRequest) aynı sayı. Daha uzun bir
 * kural koymak, patronun kuryesine veremeyeceği bir parola üretirdi (saha gerçeği: parolalar
 * kısadır ve BRIEF bunu açıkça söyler); daha kısası ise sunucu tarafında zaten reddedilir.
 */
class UpdateCredentialsRequest extends FormRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // İkisi de OPSİYONEL ama en az biri gerekli (withValidator). Parolayı değiştirmeden
            // kullanıcı adını düzeltmek meşru bir istektir ve tersi de öyle.
            'username' => [
                'sometimes',
                'string',
                'regex:/^[a-z0-9._-]{3,60}$/',
                // Tekillik BAYİ İÇİNDE aranır: iki farklı bayide aynı "mehmet" meşrudur.
                // Kendi satırı hariç tutulur, yoksa adını değiştirmeyen bir kayıt kendine çarpar.
                Rule::unique('users', 'username')
                    ->where('tenant_id', $this->user()->tenant_id)
                    ->ignore($this->route('user')),
            ],
            'password' => ['sometimes', 'string', 'min:4', 'max:72'],
        ];
    }

    protected function prepareForValidation(): void
    {
        // Kullanıcı adı DAİMA küçük harf: giriş sorgusu (`sipario_login_lookup`) `lower()` ile
        // arar. Patron "Mehmet" yazıp kaydettiğinde kurye "mehmet" ile girebilmeli; büyük harfi
        // reddetmek yerine sessizce indirmek burada doğru davranıştır — kullanıcının niyeti açık.
        if ($this->has('username')) {
            $this->merge(['username' => mb_strtolower(trim((string) $this->input('username')))]);
        }
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function ($v) {
            if (! $this->has('username') && ! $this->has('password')) {
                $v->errors()->add('username', 'Kullanıcı adı ya da parola gönderilmeli.');
            }
        });
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'username.regex' => 'Kullanıcı adı 3-60 karakter olmalı; küçük harf, rakam, nokta, tire ve alt çizgi kullanılabilir.',
            'username.unique' => 'Bu kullanıcı adı bu bayide zaten kullanılıyor.',
            'password.min' => 'Parola en az 4 karakter olmalı.',
        ];
    }

    /** @return array<string, string> */
    public function attributes(): array
    {
        return ['username' => 'kullanıcı adı', 'password' => 'parola'];
    }
}
