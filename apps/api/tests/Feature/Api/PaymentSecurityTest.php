<?php

namespace Tests\Feature\Api;

use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use App\Payment\IyzicoPaymentGateway;
use App\Payment\SubscriptionService;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use RuntimeException;
use Tests\ApiTestCase;

/**
 * FAZ 5b GÜVENLİK SERTLEŞTİRME (reviewer bulgusu). IyzicoPaymentGateway::verify() FAIL-CLOSED:
 * callback GÖVDESİNDEKİ paymentStatus'a ASLA güvenmez → iyzico'ya sunucu-sunucu retrieve yapar,
 * sonuç ORADAN türer. Forge edilen gövde ({paymentStatus:SUCCESS}) aboneliği AKTİVE ETMEZ.
 *
 * GERÇEK IyzicoPaymentGateway ile koşar (FakePaymentGateway DEĞİL). Http::fake ile iyzico retrieve
 * cevabı taklit edilir (bu ortamda gerçek sandbox anahtarı yok).
 */
class PaymentSecurityTest extends ApiTestCase
{
    private const BASE = 'https://sandbox-api.iyzipay.com';

    private function configuredGateway(): IyzicoPaymentGateway
    {
        return new IyzicoPaymentGateway('test-key', 'test-secret', self::BASE);
    }

    #[Test]
    public function forge_edilen_callback_govdesi_aboneligi_aktive_etmez(): void
    {
        // Anahtarsız GERÇEK gateway (üretimdeki mayın: gövde-güven). verify() fail-closed → aktivasyon YOK.
        $service = new SubscriptionService(new IyzicoPaymentGateway('', '', self::BASE));

        $a = $this->makeTenant('a');
        $tenantId = $a['tenant']->id;
        // Bilinen sabit durum: kilitli + geçmiş valid_until (aktivasyon olmadığını netçe görmek için).
        $this->asOwner(fn () => Tenant::query()->whereKey($tenantId)
            ->update(['status' => 'locked', 'valid_until' => now()->subDay(), 'locked_at' => now()->subDay()]));

        // Saldırganın hedeflediği 'initiated' kaydı (owner ile seed).
        $this->asOwner(fn () => SubscriptionPayment::query()->create([
            'tenant_id' => $tenantId, 'amount_kurus' => 120000, 'currency' => 'TRY',
            'provider' => 'iyzico', 'provider_ref' => 'forged-ref', 'status' => 'initiated',
            'occurred_at' => now(),
        ]));

        // Saldırgan sahte SUCCESS gövdesi POST'lar (CSRF muaf callback). Fail-closed: throw.
        try {
            $service->handleCallback(['provider_ref' => 'forged-ref', 'paymentStatus' => 'SUCCESS']);
            $this->fail('Forge edilen gövde ile handleCallback fail-closed olmalıydı (throw).');
        } catch (RuntimeException) {
            // beklenen: anahtarsız verify() açık hata → aktivasyon YOK.
        }

        // Abonelik AKTİVE EDİLMEDİ: durum ve valid_until DEĞİŞMEDİ.
        $tenant = $this->asOwner(fn () => Tenant::query()->find($tenantId));
        $this->assertSame('locked', $tenant->status->value, 'Forge edilen ödeme bayiyi aktive ETMEMELİ.');
        $this->assertTrue($tenant->valid_until->isPast(), 'valid_until uzatılmamalı.');

        $success = $this->asOwner(fn () => SubscriptionPayment::query()
            ->where('provider_ref', 'forged-ref')->where('status', 'success')->count());
        $this->assertSame(0, $success, 'Forge edilen ref için success kaydı oluşmamalı.');
    }

    #[Test]
    public function verify_govde_paymentstatusuna_guvenmez_iyzico_retrievei_esastir(): void
    {
        // iyzico retrieve SUCCESS + doğru tutar döner; gövdede FAILURE forge edilmiş → yine SUCCESS.
        Http::fake([
            '*/checkoutform/auth/ecom/detail' => Http::response([
                'status' => 'success', 'paymentStatus' => 'SUCCESS',
                'conversationId' => 'real-ref', 'paidPrice' => '1200.00',
            ], 200),
        ]);

        $result = $this->configuredGateway()->verify(['token' => 'tok-123', 'paymentStatus' => 'FAILURE']);

        $this->assertTrue($result->success, 'Sonuç iyzico retrieve\'inden gelmeli (gövdedeki FAILURE yok sayılır).');
        $this->assertSame('real-ref', $result->providerRef);
    }

    #[Test]
    public function verify_iyzico_failure_dondurunce_govde_success_olsa_bile_reddedilir(): void
    {
        Http::fake([
            '*/checkoutform/auth/ecom/detail' => Http::response([
                'status' => 'success', 'paymentStatus' => 'FAILURE',
                'conversationId' => 'ref', 'paidPrice' => '1200.00',
            ], 200),
        ]);

        // Saldırgan gövdede SUCCESS forge etse de iyzico FAILURE dedi → reddedilir.
        $result = $this->configuredGateway()->verify(['token' => 'tok', 'paymentStatus' => 'SUCCESS']);
        $this->assertFalse($result->success, 'Gövdedeki SUCCESS iyzico FAILURE\'ını ezememeli.');
    }

    #[Test]
    public function verify_tutar_manipulasyonunu_reddeder(): void
    {
        // iyzico SUCCESS ama ödenen tutar beklenenden düşük (saldırgan 1 kuruş ödedi) → reddedilir.
        Http::fake([
            '*/checkoutform/auth/ecom/detail' => Http::response([
                'status' => 'success', 'paymentStatus' => 'SUCCESS',
                'conversationId' => 'ref', 'paidPrice' => '1.00',
            ], 200),
        ]);

        $result = $this->configuredGateway()->verify(['token' => 'tok']);
        $this->assertFalse($result->success, 'Tutar beklenenle eşleşmiyorsa (manipülasyon) reddedilmeli.');
    }

    #[Test]
    public function verify_tokensiz_govde_fail_closed(): void
    {
        // Anahtar var ama gövdede token yok → iyzico'ya sorulamaz → doğrulanamaz → success:false.
        $result = $this->configuredGateway()->verify(['provider_ref' => 'ref', 'paymentStatus' => 'SUCCESS']);
        $this->assertFalse($result->success, 'Token olmadan (retrieve yapılamaz) fail-closed olmalı.');
        Http::assertNothingSent();
    }

    #[Test]
    public function verify_retrieve_hatasinda_fail_closed(): void
    {
        // iyzico retrieve başarısız (status != success) → açık hata (fail-closed; sessiz success YOK).
        Http::fake([
            '*/checkoutform/auth/ecom/detail' => Http::response(['status' => 'failure'], 200),
        ]);

        $this->expectException(RuntimeException::class);
        $this->configuredGateway()->verify(['token' => Str::uuid7()->toString()]);
    }
}
