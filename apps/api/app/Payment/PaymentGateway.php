<?php

namespace App\Payment;

/**
 * Ödeme sağlayıcı SOYUTLAMASI (FAZ 5b — SyncApi arayüz+fake deseninin ikizi). Gerçek entegrasyon
 * (IyzicoPaymentGateway) ile test sahtesi (FakePaymentGateway) bu arayüzü uygular → ödeme akışı
 * gerçek ağ/iyzico olmadan test edilebilir.
 *
 * Abonelik durumunun TEK doğru kaynağı SUNUCUdur (BRIEF): gateway yalnız ödeme başlatır ve callback'i
 * doğrular; valid_until'ı uzatma kararı SubscriptionService'te (sunucuda) verilir. Kart verisi
 * gateway'den geçmez — iyzico saklar (KVKK).
 */
interface PaymentGateway
{
    /** Ödeme başlat → sağlayıcı referansı (+ varsa yönlendirme). */
    public function initiate(PaymentInitiationRequest $request): PaymentInitiation;

    /**
     * Callback/webhook doğrula → sonuç. İmza/bütünlük doğrulaması sağlayıcıya özgü (Iyzico'da HMAC).
     *
     * @param  array<string, mixed>  $callback
     */
    public function verify(array $callback): PaymentResult;
}
