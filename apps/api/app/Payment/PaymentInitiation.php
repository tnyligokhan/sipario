<?php

namespace App\Payment;

/**
 * Ödeme başlatma sonucu (FAZ 5b): sağlayıcı referansı (idempotensi anahtarı) + kullanıcının
 * yönlendirileceği ödeme sayfası (varsa). status başlangıçta 'initiated'.
 */
final class PaymentInitiation
{
    public function __construct(
        public readonly string $providerRef,
        public readonly ?string $redirectUrl = null,
        public readonly string $status = 'initiated',
    ) {}
}
