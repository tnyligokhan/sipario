<?php

namespace App\Payment;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * iyzico ödeme sağlayıcısı (FAZ 5b — SANDBOX). DECISIONS: TR yerleşik (KVKK/veri yerleşimi), kart
 * saklama + abonelik olgun. Yıllık PEŞİN tek çekim (checkout form). Kartı iyzico saklar, biz DEĞİL.
 *
 * GÜVENLİK (reviewer bulgusu — FAIL-CLOSED): verify() callback POST GÖVDESİNDEKİ `paymentStatus`'a
 * ASLA güvenmez (gövde forge edilebilir + callback CSRF-muaf → aksi halde saldırgan sahte SUCCESS
 * POST'layıp bedava abonelik alırdı). Bunun yerine iyzico'ya SUNUCU-SUNUCU geri-sorgu (checkout-form
 * retrieve) yapılır; sonuç YALNIZ iyzico'nun döndürdüğü paymentStatus + tutardan türetilir. Retrieve
 * yapılamıyorsa (anahtar yok / hata) → success:false (fail-closed) veya açık hata; ASLA sessiz success.
 *
 * AÇIK / DOĞRULANMADI: HMAC imza + initialize/retrieve akışının YAPISI kuruldu ama GERÇEK sandbox
 * çağrısı bu ortamda DOĞRULANMADI (sandbox anahtarı/hesabı insan/PLAN işidir). Anahtar gelince
 * sandbox'ta forged-body reddi + gerçek retrieve + IYZWSv2 imza doğrulaması sınanacak (PLAN). Anahtar
 * yoksa initiate/verify RuntimeException fırlatır — sessiz yanlış davranış YERİNE açık hata.
 *
 * @see https://docs.iyzico.com (checkout form initialize + retrieve + IYZWSv2 auth)
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
     * FAIL-CLOSED doğrulama. Callback gövdesinden YALNIZ `token` alınır (status DEĞİL); iyzico'ya
     * sunucu-sunucu retrieve yapılıp sonuç ORADAN türetilir. Gövdedeki `paymentStatus` KULLANILMAZ
     * (forge edilebilir). Token yoksa veya retrieve başarısızsa → success:false. Ayrıca tutar
     * manipülasyonuna karşı: iyzico'nun döndürdüğü ödenen tutar beklenen fiyatla (config) eşleşmeli.
     *
     * @param  array<string, mixed>  $callback
     */
    public function verify(array $callback): PaymentResult
    {
        $this->assertConfigured(); // anahtar yoksa açık hata (fail-closed; gövdeden SUCCESS türetilemez)

        $token = (string) ($callback['token'] ?? '');
        if ($token === '') {
            // token olmadan iyzico'ya sorulamaz → doğrulanamaz → aktive ETME (fail-closed).
            $ref = (string) ($callback['conversationId'] ?? $callback['provider_ref'] ?? '');

            return new PaymentResult(providerRef: $ref, success: false);
        }

        $retrieved = $this->retrievePaymentStatus($token); // GERÇEK iyzico geri-sorgu (gövde-güven YOK)

        $ref = (string) ($retrieved['conversationId'] ?? '');
        $paidStatus = (string) ($retrieved['paymentStatus'] ?? '');
        $expectedKurus = (int) config('subscription.price_kurus');
        $amountOk = isset($retrieved['paidPrice'])
            && $this->kurusFromDecimal((string) $retrieved['paidPrice']) === $expectedKurus;

        // Başarı YALNIZ iyzico'nun döndürdüğü SUCCESS + doğru tutarla; gövdedeki hiçbir değer sayılmaz.
        return new PaymentResult(providerRef: $ref, success: $paidStatus === 'SUCCESS' && $amountOk);
    }

    /**
     * iyzico checkout-form-retrieve — SUNUCU-SUNUCU geri-sorgu (gövde-güven yerine bunun sonucu esas).
     * IYZWSv2 imzalı HTTP; anahtarsız assertConfigured (verify üstünde) patlar → forge edilen gövde
     * ASLA success üretemez. GERÇEK sandbox doğrulaması (imza + durum) anahtarla sınanacak — AÇIK (PLAN).
     *
     * @return array<string, mixed>
     */
    private function retrievePaymentStatus(string $token): array
    {
        $uriPath = '/payment/iyzipos/checkoutform/auth/ecom/detail';
        $body = ['locale' => 'tr', 'token' => $token];

        $response = Http::withHeaders([
            'Authorization' => $this->authHeader($uriPath, $body),
            'Content-Type' => 'application/json',
        ])->post($this->baseUrl.$uriPath, $body);

        /** @var array<string, mixed> $json */
        $json = $response->json() ?? [];
        if (($json['status'] ?? null) !== 'success') {
            throw new RuntimeException('iyzico ödeme doğrulaması (retrieve) alınamadı.');
        }

        return $json;
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

    /** iyzico ondalık string → kuruş (ör. "1200.00" → 120000). Tutar eşleşme kontrolü için. */
    private function kurusFromDecimal(string $decimal): int
    {
        return (int) round(((float) $decimal) * 100);
    }
}
