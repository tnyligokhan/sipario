<?php

namespace App\Livewire\Site;

use App\Payment\ConsentRequiredException;
use App\Payment\DuplicateEmailException;
use App\Payment\SubscriptionService;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Public ÜYELİK (Faz 5b, auth YOK). Bayi adı/e-posta/parola/telefon + KVKK onayı → trial tenant+patron
 * (SubscriptionService, owner ile). Başarıda oturuma tenant konur → /abonelik'e yönlendirilir.
 * Mağaza kuralı: bu ekran WEB'dedir; mobil uygulamada KAYIT YOKtur.
 */
#[Layout('components.layouts.app')]
class Register extends Component
{
    public string $name = '';

    public string $email = '';

    public string $password = '';

    public string $phone = '';

    public bool $kvkk = false;

    public function submit(): mixed
    {
        $this->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:8'],
            'phone' => ['nullable', 'string', 'max:20'],
        ]);

        try {
            $result = app(SubscriptionService::class)->register(
                $this->name, $this->email, $this->password, $this->phone !== '' ? $this->phone : null, $this->kvkk,
            );
        } catch (ConsentRequiredException $e) {
            $this->addError('kvkk', $e->getMessage());

            return null;
        } catch (DuplicateEmailException $e) {
            $this->addError('email', $e->getMessage());

            return null;
        }

        session([
            'subscription_tenant_id' => $result['tenant']->id,
            'subscription_email' => $result['patron']->email,
        ]);

        return redirect()->route('subscription.subscribe');
    }

    public function render(): mixed
    {
        return view('livewire.site.register');
    }
}
