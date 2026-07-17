<?php

namespace App\Livewire\Site;

use App\Payment\ConsentRequiredException;
use App\Payment\SubscriptionService;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Abonelik/ödeme (Faz 5b, public). Fiyat/paket config'den. ZORUNLU hukuk onayları (mesafeli satış +
 * ön bilgilendirme + KVKK) işaretlenmeden ödeme BAŞLAMAZ. "Abone Ol" → SubscriptionService.startCheckout
 * → iyzico yönlendirmesi (gerçek). Ödeme başarısı sunucuda valid_until'ı uzatır (callback).
 *
 * Metinler PLACEHOLDER — tam hukuk metni + onayı insan/hukuk işidir (5d, AÇIK).
 */
#[Layout('components.layouts.app')]
class Subscribe extends Component
{
    public bool $distanceSales = false;

    public bool $preinfo = false;

    public bool $kvkk = false;

    public function mount(): void
    {
        // Üyelik sonrası oturumda tenant olmalı (public site returning-user login'i AÇIK — sonraki iş).
        abort_if(session('subscription_tenant_id') === null, 403, 'Önce üyelik oluşturun.');
    }

    public function pay(): mixed
    {
        $tenantId = (string) session('subscription_tenant_id');
        $email = (string) session('subscription_email', '');

        try {
            $init = app(SubscriptionService::class)->startCheckout($tenantId, $email, [
                'distance_sales' => $this->distanceSales,
                'preinfo' => $this->preinfo,
                'kvkk' => $this->kvkk,
            ]);
        } catch (ConsentRequiredException $e) {
            $this->addError('consents', $e->getMessage());

            return null;
        }

        if ($init->redirectUrl !== null) {
            return redirect()->away($init->redirectUrl); // gerçek iyzico ödeme sayfası
        }

        // Yönlendirme yoksa (yapılandırma eksik/sandbox) bilgi ver — ödeme başlatıldı kaydı düştü.
        return redirect()->route('subscription.subscribe')->with('status', 'Ödeme başlatıldı.');
    }

    public function render(): mixed
    {
        return view('livewire.site.subscribe', [
            'priceKurus' => (int) config('subscription.price_kurus'),
            'currency' => (string) config('subscription.currency'),
        ]);
    }
}
