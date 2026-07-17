<?php

namespace App\Livewire\Panel;

use Illuminate\Support\Facades\Auth;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Panel giriş ekranı (Faz 5c). `admin` guard ile doğrular (bayilerin `users` tablosundan ayrı).
 * Nötr hata mesajı (kullanıcı numaralandırma sızdırmaz).
 */
#[Layout('components.layouts.app')]
class Login extends Component
{
    public string $email = '';

    public string $password = '';

    public function authenticate(): mixed
    {
        $this->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        if (! Auth::guard('admin')->attempt(['email' => $this->email, 'password' => $this->password])) {
            $this->addError('email', 'Giriş bilgileri hatalı.');

            return null;
        }

        session()->regenerate();

        return redirect()->route('panel.tenants');
    }

    public function render(): mixed
    {
        return view('livewire.panel.login');
    }
}
