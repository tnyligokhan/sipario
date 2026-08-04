<?php

namespace App\Abonelik;

use App\Enums\BillingPeriod;
use App\Enums\TenantStatus;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * ELLE ÖDEME KAYDI (panelin "Ödeme Ekle" akışı; IBAN/havale ve elden tahsilat).
 *
 * Panelin EN HASSAS yetkisi budur: bir satır, bir bayinin aboneliğini uzatır. Bu yüzden dört kural
 * pazarlıksızdır:
 *
 *  1. TEK TRANSACTION. Ödeme satırı yazılıp tenant uzatılmazsa para alınmış ama hesap kapalı kalır;
 *     tersi olursa bedava abonelik. İkisi birlikte olur ya da hiçbiri olmaz.
 *  2. İDEMPOTENS. Aynı `provider_ref` ile ikinci çağrı YENİ AKTİVASYON ÜRETMEZ. Havale bildirimi
 *     eşleştirmesi ve panelde çift tıklama gerçek senaryolardır; DB'deki kısmi tekil indeks
 *     (`subscription_payments_success_ref`) son emniyettir ama kullanıcıya 23505 göstermeyiz.
 *  3. SÜRE GERİ ALINMAZ. Taban `valid_until > now ? valid_until : now`. Erken ödeyen bayinin kalan
 *     günleri yanmaz; süresi geçmiş bayide de bitiş bugünden başlar (geçmişe uzatma anlamsızdır).
 *  4. APPEND-ONLY. Mevcut ödeme satırı GÜNCELLENMEZ; her kayıt yeni satırdır (tablo zaten DB
 *     seviyesinde UPDATE/DELETE'e kapalı — 000506).
 *
 * BAĞLANTI: `pgsql_owner` (bkz. AbonelikServisi). `sipario_panel`in subscription_payments'ta yalnız
 * SELECT'i vardır — panel para kaydını doğrudan yazamaz, bu servisten geçer.
 */
class OdemeKayitServisi extends AbonelikServisi
{
    /**
     * Ödemeyi kaydeder ve aboneliği uzatır.
     *
     * @param  string  $method  'iban' | 'elden' → subscription_payments.provider
     * @param  string  $coversPeriod  insan okunur dönem etiketi ("Ağustos 2026")
     * @param  BillingPeriod|null  $period  null → tenant.billing_period → yoksa AYLIK
     *                                      (tasarımın modal notu: "abonelik bitişi 1 ay uzatılır")
     * @param  string|null  $providerRef  idempotens anahtarı. null → her çağrıda benzersiz üretilir,
     *                                    yani çift tıklamayı ÇAĞIRAN engellemek zorundadır. Tekrarı
     *                                    olabilecek yollar (havale bildirimi eşleştirme) kendi
     *                                    kararlı anahtarını verir.
     * @return array{payment: SubscriptionPayment, tenant: Tenant}
     */
    public function kaydet(
        string $tenantId,
        int $amountKurus,
        string $method,
        string $coversPeriod,
        ?BillingPeriod $period = null,
        ?string $note = null,
        ?string $adminId = null,
        ?Carbon $occurredAt = null,
        ?string $providerRef = null,
    ): array {
        if ($amountKurus <= 0) {
            throw new GecersizTutarException('Ödeme tutarı sıfırdan büyük olmalıdır.');
        }
        if (! in_array($method, ['iban', 'elden'], true)) {
            throw new GecersizTutarException('Tahsilat yöntemi IBAN veya elden olmalıdır.');
        }

        $ref = $providerRef ?? 'manual:'.Str::uuid7();
        $occurredAt ??= now();

        return $this->db()->transaction(function () use ($tenantId, $amountKurus, $method, $coversPeriod, $period, $note, $adminId, $occurredAt, $ref) {
            /** @var Tenant $tenant */
            $tenant = Tenant::on($this->connection)->lockForUpdate()->findOrFail($tenantId);

            // İDEMPOTENS: bu referansla zaten başarılı bir ödeme varsa ikinci kez aktive ETME.
            /** @var SubscriptionPayment|null $mevcut */
            $mevcut = SubscriptionPayment::on($this->connection)
                ->where('provider_ref', $ref)->where('status', 'success')->first();
            if ($mevcut !== null) {
                return ['payment' => $mevcut, 'tenant' => $tenant];
            }

            $donem = $period ?? $tenant->billing_period ?? BillingPeriod::Monthly;

            $payment = SubscriptionPayment::on($this->connection)->create([
                'tenant_id' => $tenantId,
                'amount_kurus' => $amountKurus,
                'currency' => (string) config('subscription.currency'),
                'provider' => $method,
                'provider_ref' => $ref,
                'status' => 'success',
                'covers_period' => $coversPeriod,
                'period' => $donem->value,
                'note' => $note,
                'recorded_by_admin_id' => $adminId,
                // Hukuk onayları ELLE ödemede alınmaz: sözleşme/ön bilgilendirme onayı siteden
                // üyelik/checkout anında verilir. Buraya sahte bir onay sürümü yazmak, KVKK
                // izinin kendisini yalanlardı.
                'consent_version' => null,
                'consented_at' => null,
                'occurred_at' => $occurredAt,
            ]);

            $taban = ($tenant->valid_until !== null && $tenant->valid_until->greaterThan(now()))
                ? $tenant->valid_until
                : now();

            $tenant->forceFill([
                'status' => TenantStatus::Active->value,
                'billing_period' => $donem->value,
                'valid_until' => $donem->uzat($taban),
                'locked_at' => null,
            ])->save();

            // Nötr denetim: tutar/not YAZILMAZ, yöntem ve dönem yazılır (eylemin türü).
            $this->denetle($adminId, $tenantId, 'payment_manual', $method.':'.$donem->value);

            return ['payment' => $payment, 'tenant' => $tenant];
        });
    }

    /**
     * Bir bayinin ödeme geçmişi (panelin firma detayı). Yalnız BAŞARILI kayıtlar — 'initiated'
     * satırları ödeme değil GİRİŞİMdir ve listede gösterilirse ödenmemiş para ödenmiş görünür.
     *
     * @return Collection<int, SubscriptionPayment>
     */
    public function bayiOdemeleri(string $tenantId): Collection
    {
        return SubscriptionPayment::on($this->connection)
            ->where('tenant_id', $tenantId)
            ->where('status', 'success')
            ->orderByDesc('occurred_at')
            ->get();
    }

    /**
     * Tüm ödemeler (panelin "Ödemeler" ekranı). $ay verilirse 'YYYY-MM' süzgeci uygulanır (TR günü:
     * PanelStatsService ile aynı sabit +03:00, DST yok).
     *
     * @return Collection<int, SubscriptionPayment>
     */
    public function odemeler(?string $ay = null, int $limit = 500): Collection
    {
        $q = SubscriptionPayment::on($this->connection)
            ->where('status', 'success')
            ->orderByDesc('occurred_at')
            ->limit($limit);

        if ($ay !== null) {
            $q->whereRaw("to_char(occurred_at AT TIME ZONE 'Etc/GMT-3', 'YYYY-MM') = ?", [$ay]);
        }

        return $q->get();
    }
}
