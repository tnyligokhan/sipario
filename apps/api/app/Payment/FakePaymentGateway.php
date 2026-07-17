<?php

namespace App\Payment;

use Illuminate\Support\Str;

/**
 * Test sahtesi (FAZ 5b — SyncApi'nin FakeSyncApi ikizi). Gerçek ağ/iyzico olmadan ödeme akışını
 * sürer. `verify` sonucu `$nextVerifyResult` ile ayarlanır (başarı/başarısızlık senaryoları).
 * `initiate` deterministik/kontrollü bir providerRef döner (idempotensi testleri için sabitlenebilir).
 */
class FakePaymentGateway implements PaymentGateway
{
    public bool $nextVerifyResult = true;

    public ?string $forcedProviderRef = null;

    /** @var list<PaymentInitiationRequest> */
    public array $initiated = [];

    public function initiate(PaymentInitiationRequest $request): PaymentInitiation
    {
        $this->initiated[] = $request;
        $ref = $this->forcedProviderRef ?? ('fake-'.Str::uuid7());

        return new PaymentInitiation(providerRef: $ref, redirectUrl: null, status: 'initiated');
    }

    /**
     * @param  array<string, mixed>  $callback
     */
    public function verify(array $callback): PaymentResult
    {
        $ref = (string) ($callback['provider_ref'] ?? $this->forcedProviderRef ?? '');
        // callback['success'] verilmişse onu kullan; yoksa ayarlı varsayılan.
        $success = array_key_exists('success', $callback) ? (bool) $callback['success'] : $this->nextVerifyResult;

        return new PaymentResult(providerRef: $ref, success: $success);
    }
}
