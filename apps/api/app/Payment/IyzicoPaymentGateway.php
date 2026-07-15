<?php

namespace App\Payment;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * iyzico ödeme sağlayıcısı (FAZ 5b — SANDBOX). DECISIONS: TR yerleşik (KVKK/veri yerleşimi), kart
 * saklama + abonelik olgun. Yıllık PEŞİN tek çekim (checkout form). Kartı iyzico saklar, biz DEĞİL.
 *
 * AÇIK / DOĞRULANMADI: Bu sınıf iyzico v2 HMAC imza + checkout-form-initialize akışının YAPISINI
 * kurar ama GERÇEK sandbox çağrısı bu ortamda DOĞRULANMADI (sandbox anahtarı/hesabı insan/PLAN işidir).
 * ÜRETİM anahtarı da PLAN'da. Tüm testler FakePaymentGateway ile koşar; gerçek entegrasyon anahtar
 * gelince sandbox'ta sınanacak (webhook imza doğrulaması dahil). Anahtar yoksa initiate/verify
 * RuntimeException fırlatır — sessiz yanlış davranış YERİNE açık hata.
 *
 * @see https://docs.iyzico.com (checkout form + IYZWSv2 auth)
 */
class IyzicoPaymentGateway implements PaymentGateway
{
    public function __construct(
        private readonly string $apiKey,
        private readonly string $secretKey,
        private readonly string $baseUrl,
    ) {}

    public function initiate(PaymentInitiationRequest $request): PaymentInitiation
    {
        $this->assertConfigured();

        $conversationId = (string) Str::uuid7(); // providerRef = bizim ürettiğimiz idempotensi anahtarı
        $uriPath = '/payment/iyzipos/checkoutform/initialize/auth/ecom';
        $body = [
            'locale' => 'tr',
            'conversationId' => $conversationId,
            'price' => $this->toDecimal($request->amountKurus),
            'paidPrice' => $this->toDecimal($request->amountKurus),
            'currency' => $request->currency,
            'basketId' => $request->tenantId,
            'paymentGroup' => 'SUBSCRIPTION',
            'callbackUrl' => route('subscription.callback'),
            // buyer/basketItems iyzico zorunlu alanları — gerçek entegrasyonda doldurulacak (AÇIK).
        ];

        $response = Http::withHeaders([
            'Authorization' => $this->authHeader($uriPath, $body),
            'Content-Type' => 'application/json',
        ])->post($this->baseUrl.$uriPath, $body);

        /** @var array<string, mixed> $json */
        $json = $response->json() ?? [];
        if (($json['status'] ?? null) !== 'success') {
            throw new RuntimeException('iyzico ödeme başlatılamadı.');
        }

        return new PaymentInitiation(
            providerRef: $conversationId,
            redirectUrl: isset($json['paymentPageUrl']) ? (string) $json['paymentPageUrl'] : null,
        );
    }

    /**
     * @param  array<string, mixed>  $callback
     */
    public function verify(array $callback): PaymentResult
    {
        $this->assertConfigured();

        // GERÇEK: callback token'ıyla /payment/iyzipos/checkoutform/auth/ecom/detail çağrılıp
        // paymentStatus + imza doğrulanır. Bu ortamda DOĞRULANMADI (sandbox anahtarı yok) — AÇIK.
        $conversationId = (string) ($callback['conversationId'] ?? $callback['provider_ref'] ?? '');
        $status = (string) ($callback['paymentStatus'] ?? $callback['status'] ?? '');

        return new PaymentResult(providerRef: $conversationId, success: $status === 'SUCCESS');
    }

    private function assertConfigured(): void
    {
        if ($this->apiKey === '' || $this->secretKey === '') {
            throw new RuntimeException('iyzico anahtarları yapılandırılmadı (sandbox/üretim anahtarı PLAN).');
        }
    }

    /**
     * iyzico IYZWSv2 HMAC-SHA256 imzası.
     *
     * @param  array<string, mixed>  $body
     */
    private function authHeader(string $uriPath, array $body): string
    {
        $randomKey = (string) Str::uuid7();
        $payload = $randomKey.$uriPath.((string) json_encode($body));
        $signature = hash_hmac('sha256', $payload, $this->secretKey);
        $auth = 'apiKey:'.$this->apiKey.'&randomKey:'.$randomKey.'&signature:'.$signature;

        return 'IYZWSv2 '.base64_encode($auth);
    }

    /** Kuruş → iyzico ondalık string (ör. 120000 → "1200.00"). Para int kuruş; sınırda dönüşüm. */
    private function toDecimal(int $amountKurus): string
    {
        return number_format($amountKurus / 100, 2, '.', '');
    }
}
