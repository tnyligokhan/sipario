<?php

namespace App\Payment;

use App\Enums\TenantStatus;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Support\Facades\DB;

/**
 * FAZ 5b — abonelik/ödeme iş akışı (public site). Ödeme sağlayıcısı SOYUT (PaymentGateway) → Fake ile
 * test edilir. Abonelik durumunun TEK doğru kaynağı SUNUCUdur (BRIEF): ödeme başarısı burada (owner ile)
 * valid_until'ı uzatır; istemci karar vermez.
 *
 * AYRICALIKLI yazımlar owner bağlantısıyla: tenant yaratma (Provisioning), aktivasyon (tenants UPDATE),
 * subscription_payments INSERT — hepsi RLS-üstü meşru (public callback'te tenant session yok). sipario_app
 * (RLS) ETKİLENMEZ; public site iş verisine dokunmaz. subscription_payments append-only (DB REVOKE).
 *
 * Callback İDEMPOTENT: aynı provider_ref success iki kez → tek aktivasyon (kontrol + partial unique index).
 * KVKK: kart verisi hiçbir yere yazılmaz; yalnız onay sürümü + zaman.
 */
class SubscriptionService
{
    private const CONN = 'pgsql_owner';

    /** Zorunlu checkout onayları (5d iskelet). */
    private const REQUIRED_CONSENTS = ['distance_sales', 'preinfo', 'kvkk'];

    public function __construct(private readonly PaymentGateway $gateway) {}

    /**
     * Public üyelik → trial tenant + patron user (valid_until = now+trial, status=trial). KVKK onayı
     * ZORUNLU. Email GLOBAL tekil (çakışma → nötr DuplicateEmailException). Tenant yaratma owner ile.
     *
     * @return array{tenant: Tenant, patron: User}
     */
    public function register(string $name, string $email, string $password, ?string $phone, bool $kvkkConsent): array
    {
        if (! $kvkkConsent) {
            throw new ConsentRequiredException('KVKK aydınlatma onayı gerekli.');
        }

        $email = mb_strtolower($email);
        if (User::on(self::CONN)->where('email', $email)->exists()) {
            throw new DuplicateEmailException('Bu e-posta ile devam edilemiyor.');
        }

        return Provisioning::createTenantWithPatron($name, $email, $password);
    }

    /**
     * Ödeme başlat: TÜM hukuk onayları ZORUNLU (işaretsiz → ConsentRequiredException, ödeme başlamaz)
     * → gateway.initiate → subscription_payments 'initiated' (onay sürümü + zaman ile). PaymentInitiation döner.
     *
     * @param  array<string, mixed>  $consents
     */
    public function startCheckout(string $tenantId, string $buyerEmail, array $consents): PaymentInitiation
    {
        $this->assertConsents($consents);

        $amount = (int) config('subscription.price_kurus');
        $currency = (string) config('subscription.currency');

        $init = $this->gateway->initiate(new PaymentInitiationRequest($tenantId, $amount, $currency, $buyerEmail));
        $this->record($tenantId, $amount, $currency, $init->providerRef, 'initiated', $this->consentVersion());

        return $init;
    }

    /**
     * Ödeme callback/webhook: doğrula → BAŞARIDA idempotent aktivasyon (valid_until=now+period,
     * status=active); BAŞARISIZDA durum değişmez + failed kaydı. Bilinmeyen provider_ref → no-op.
     *
     * @param  array<string, mixed>  $payload
     */
    public function handleCallback(array $payload): PaymentResult
    {
        $result = $this->gateway->verify($payload);

        // İdempotensi: bu provider_ref için zaten success varsa tekrar aktive etme (retry/webhook 2×).
        $alreadySucceeded = SubscriptionPayment::on(self::CONN)
            ->where('provider_ref', $result->providerRef)->where('status', 'success')->exists();
        if ($alreadySucceeded) {
            return $result;
        }

        // provider_ref'i 'initiated' kaydından tenant'a bağla (tutar/onay oradan).
        $initiated = SubscriptionPayment::on(self::CONN)
            ->where('provider_ref', $result->providerRef)->orderBy('created_at')->first();
        if ($initiated === null) {
            return $result; // bilinmeyen ref → aktivasyon yok
        }

        if (! $result->success) {
            $this->record($initiated->tenant_id, $initiated->amount_kurus, $initiated->currency,
                $result->providerRef, 'failed', null);

            return $result;
        }

        DB::connection(self::CONN)->transaction(function () use ($initiated, $result) {
            $this->record($initiated->tenant_id, $initiated->amount_kurus, $initiated->currency,
                $result->providerRef, 'success', $initiated->consent_version);
            $this->activate($initiated->tenant_id);
        });

        return $result;
    }

    /** Abonelik aktivasyonu (SUNUCU — tek doğru kaynak): valid_until ileri, status=active, kilit temizle. */
    private function activate(string $tenantId): void
    {
        $tenant = Tenant::on(self::CONN)->findOrFail($tenantId);
        $tenant->forceFill([
            'status' => TenantStatus::Active->value,
            'valid_until' => now()->addDays((int) config('subscription.period_days')),
            'locked_at' => null,
        ])->save();
    }

    private function record(string $tenantId, int $amount, string $currency, string $ref, string $status, ?string $consentVersion): void
    {
        SubscriptionPayment::on(self::CONN)->create([
            'tenant_id' => $tenantId,
            'amount_kurus' => $amount,
            'currency' => $currency,
            'provider' => 'iyzico',
            'provider_ref' => $ref,
            'status' => $status,
            'consent_version' => $consentVersion,
            'consented_at' => $consentVersion !== null ? now() : null,
            'occurred_at' => now(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $consents
     */
    private function assertConsents(array $consents): void
    {
        foreach (self::REQUIRED_CONSENTS as $key) {
            if (empty($consents[$key])) {
                throw new ConsentRequiredException('Mesafeli satış, ön bilgilendirme ve KVKK onayları gerekli.');
            }
        }
    }

    /** Kabul edilen hukuk metni sürümleri (config) — denetim için subscription_payments'a yazılır. */
    private function consentVersion(): string
    {
        /** @var array{distance_sales_version: string, preinfo_version: string, kvkk_version: string} $legal */
        $legal = config('subscription.legal');

        return "distance_sales:{$legal['distance_sales_version']};preinfo:{$legal['preinfo_version']};kvkk:{$legal['kvkk_version']}";
    }
}
