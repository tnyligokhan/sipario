<?php

namespace App\Livewire\Panel;

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Panel giriş ekranı (Faz 5c). `admin` guard ile doğrular (bayilerin `users` tablosundan ayrı).
 * Nötr hata mesajı (kullanıcı numaralandırma sızdırmaz).
 *
 * KABA KUVVET SINIRI BURADA, ROUTE'TA DEĞİL (güvenlik incelemesi 5c-3): Livewire eylemi
 * `panel/login`e değil `/livewire/update`e gider ve `ThrottleRequests` Livewire'ın KALICI middleware
 * listesinde yoktur — yani route'a `throttle:` yazmak `authenticate()`i korumaz, yalnız sayfanın ilk
 * GET'ini korurdu. Sınır bu yüzden eylemin içindedir.
 *
 * Neden panelde ayrıca gerekli: mobil giriş `throttle:login` ile korunuyordu ama panel korunmuyordu
 * ve panel çok daha değerli bir hedeftir — admin hesabı BYPASSRLS'tir, TÜM bayilerin müşteri
 * adı/telefonu/adresini görür ve 5c-3'ten beri müşteri/ürün de yazar.
 *
 * İki eksen (mobil `login` sınırlayıcısıyla aynı desen): (1) hedefli — aynı e-posta+IP'ye kaba
 * kuvvet, (2) yayılı — tek IP'den birçok hesabı deneme. Anahtarlar sha1'lenir: e-posta doğrudan
 * önbellek anahtarına girerse uzun/garip girdi anahtarı bozabilirdi.
 */
#[Layout('components.layouts.app')]
class Login extends Component
{
    /** Aynı e-posta + IP için dakikadaki azami başarısız deneme. */
    private const KIMLIK_TAVANI = 5;

    /** Tek IP'nin dakikadaki azami başarısız denemesi (hesap numaralandırma). */
    private const IP_TAVANI = 20;

    public string $email = '';

    public string $password = '';

    public function authenticate(): mixed
    {
        $this->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        foreach ($this->limitler() as [$anahtar, $tavan]) {
            if (RateLimiter::tooManyAttempts($anahtar, $tavan)) {
                $this->addError('email', 'Çok fazla başarısız deneme. '
                    .RateLimiter::availableIn($anahtar).' saniye sonra tekrar deneyin.');

                return null;
            }
        }

        if (! Auth::guard('admin')->attempt(['email' => $this->email, 'password' => $this->password])) {
            // Yalnız BAŞARISIZ denemeler sayılır; meşru kullanıcının doğru girişi kotayı yemez.
            foreach ($this->limitler() as [$anahtar]) {
                RateLimiter::hit($anahtar);
            }

            $this->addError('email', 'Giriş bilgileri hatalı.');

            return null;
        }

        foreach ($this->limitler() as [$anahtar]) {
            RateLimiter::clear($anahtar);
        }

        session()->regenerate();

        // Son giriş damgası (hesaplar ekranı bunu gösterir): kullanılmayan bir panel hesabı,
        // kapatılması gerekeni gösteren en basit sinyaldir.
        Auth::guard('admin')->user()?->forceFill(['last_login_at' => now()])->save();

        return redirect()->route('panel.dashboard');
    }

    public function render(): mixed
    {
        return view('livewire.panel.login');
    }

    /**
     * Hız sınırı anahtarları ve tavanları: [anahtar, tavan].
     *
     * @return list<array{0: string, 1: int}>
     */
    private function limitler(): array
    {
        $ip = (string) request()->ip();

        return [
            ['panel-giris:kimlik:'.sha1(Str::lower(trim($this->email)).'|'.$ip), self::KIMLIK_TAVANI],
            ['panel-giris:ip:'.sha1($ip), self::IP_TAVANI],
        ];
    }
}
