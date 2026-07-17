<?php

namespace App\Livewire\Site;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Public site GİRİŞ (Faz 5b açık kapatma) — mevcut bayinin patronu web'den girip YENİDEN abone olabilsin.
 * Üyelikteki (Register) AYNI web session'ı kurar (tenant bağlamı) → /abonelik'e erişim açılır.
 *
 * Doğrulama API login deseni: `sipario_login_lookup` (SECURITY DEFINER, cross-tenant deterministik tek
 * satır) + `Hash::check`. Zamanlama yan-kanalı: satır yoksa da SABİT dummy hash'e karşı check koşulur
 * (e-posta var/yok sızmaz). Nötr hata (numaralandırma önlenir). KVKK: login'e PII loglanmaz.
 *
 * ÖNEMLİ — API login'den FARK: burada abonelik durumu (valid_until/tenant status) KONTROL EDİLMEZ;
 * SÜRESİ DOLMUŞ bayi tam da ÖDEME YAPMAK için giriş yapar (billing sitesi). Yalnız kullanıcı `active`
 * olmalı. Mağaza kuralı: bu giriş WEB'dedir; mobil uygulamada siteye giriş/link YOKtur.
 */
#[Layout('components.layouts.app')]
class Login extends Component
{
    /**
     * Zamanlama yan-kanalı önlemi: e-posta bulunamadığında da bu SABİT bcrypt hash'ine karşı check
     * koşulur (AuthController ile aynı değer; cost=12 üretim BCRYPT_ROUNDS ile eşleşir).
     */
    private const DUMMY_PASSWORD_HASH = '$2y$12$SIPdK92BiNANCVLYxTNjPOWYDzM9szOpCdGt9bIA3l82vGXOBI0rS';

    public string $email = '';

    public string $password = '';

    public function authenticate(): mixed
    {
        $this->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $row = DB::selectOne('SELECT * FROM sipario_login_lookup(?)', [$this->email]);

        // Hash::check HER ZAMAN koşar (satır yoksa dummy hash'e karşı) → yanıt süresi e-postanın
        // varlığını sızdırmaz. Kısa-devre YOK: önce doğrula, sonra karar ver.
        $passwordValid = Hash::check($this->password, $row->password ?? self::DUMMY_PASSWORD_HASH);

        if ($row === null || ! $passwordValid || $row->status !== 'active') {
            $this->addError('email', 'E-posta veya parola hatalı.');

            return null;
        }

        // Register'ın kurduğu AYNI web session (tenant bağlamı) → /abonelik açılır.
        session([
            'subscription_tenant_id' => $row->tenant_id,
            'subscription_email' => $row->email,
        ]);

        return redirect()->route('subscription.subscribe');
    }

    public function render(): mixed
    {
        return view('livewire.site.login');
    }
}
