<?php

namespace App\Payment;

/**
 * Ödeme callback/webhook doğrulama sonucu (FAZ 5b). success=true → abonelik aktive edilir (SUNUCU
 * tek doğru kaynak). providerRef idempotensi anahtarıdır (aynı ref iki kez → tek aktivasyon).
 */
final class PaymentResult
{
    public function __construct(
        public readonly string $providerRef,
        public readonly bool $success,
    ) {}
}
