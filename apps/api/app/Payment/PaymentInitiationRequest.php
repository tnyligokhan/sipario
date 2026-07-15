<?php

namespace App\Payment;

/**
 * Ödeme başlatma isteği (FAZ 5b). Para İMZASIZ int KURUŞ (float yok). Kart verisi TAŞIMAZ — kartı
 * iyzico saklar, biz DEĞİL (KVKK kırmızı çizgi #4). Yalnız tutar + kimlik + alıcı e-postası.
 */
final class PaymentInitiationRequest
{
    public function __construct(
        public readonly string $tenantId,
        public readonly int $amountKurus,
        public readonly string $currency,
        public readonly string $buyerEmail,
    ) {}
}
