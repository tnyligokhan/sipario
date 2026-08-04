<?php

namespace App\Abonelik;

use App\Enums\BillingPeriod;
use App\Models\PaymentNotification;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * "HAVALE GÖNDERDİM" BİLDİRİMİ — bayinin siteden yaptığı beyan + panelin eşleştirme/reddetme yolu.
 *
 * BEYAN ABONELİK UZATMAZ. Bu servisin varlık sebebi budur: `olustur()` yalnız bir bekleyen satır
 * yazar; abonelik ancak `eslestir()` çağrıldığında, yani biz banka ekstresinde parayı GÖRDÜĞÜMÜZDE
 * uzar. Aksi hâlde "gönderdim" yazan herkes bedava abone olurdu.
 *
 * EŞLEŞTİRME İDEMPOTENTTİR: gerçek ödeme kaydı `OdemeKayitServisi`e `notify:<bildirim id>` kararlı
 * referansıyla verilir. Panelde çift tıklama ya da iki operatörün aynı bildirimi aynı anda
 * kapatması tek aktivasyon üretir (subscription_payments'taki kısmi tekil indeks son emniyet).
 *
 * BAĞLANTI: `pgsql_owner`. INSERT public siteden koşar (panel rolü yok, sipario_app'in izni yok);
 * eşleştirme ise ödeme kaydı + tenant uzatma + bildirim kapanışını TEK transaction'da ister.
 *
 * KVKK: dekont görseli/hesap numarası SAKLANMAZ. Yalnız beyan edilen tutar, yöntem, referans kodu
 * ve tarih.
 */
class OdemeBildirimServisi extends AbonelikServisi
{
    /**
     * Bayinin beyanı (SİTE tarafı). `referenceCode` boş verilirse üretilir — bayi havale açıklamasına
     * bu kodu yazar ve ekstrede eşleştirmeyi biz o koddan yaparız.
     *
     * `declaredOn` GELECEKTE OLAMAZ: "yarın göndereceğim" bir beyan değildir ve bekleyen listeyi
     * kirletir.
     *
     * HUKUKİ ONAY: `$consentVersion` kabul edilen metin sürümleridir ve `consent_version` kolonuna
     * yazılır — `note` içine METİN olarak GÖMÜLMEZ (bkz. migration 005012). Bu servis onayı
     * DOĞRULAMAZ; doğrulama `SubscriptionService::manuelCheckout()`ta yapılır ve ÜÇ onay eksikse
     * `ConsentRequiredException` ile buraya hiç gelinmez. Ayrımın sebebi: onay kuralı (hangi
     * metinler, hangi sürüm) bir ÖDEME AKIŞI kararıdır ve zaten `startCheckout` ile paylaşılan
     * `assertConsents`/`consentVersion` yardımcılarında yaşar; iki yerde iki kopya kural tutmak,
     * biri güncellenince diğerinin sessizce eskimesi demekti.
     *
     * `$consentedAt` verilmezse sürüm varken `now()` olur; sürüm yoksa damga da NULL'a normalize
     * edilir — `SubscriptionService::record()`taki satırın aynısı. DB CHECK ikisinin ayrışmasını
     * zaten reddeder; buradaki normalizasyon o hatanın kullanıcıya 23514 olarak çıkmasını önler.
     */
    public function olustur(
        string $tenantId,
        int $amountKurus,
        string $method,
        ?string $referenceCode = null,
        ?Carbon $declaredOn = null,
        ?string $note = null,
        ?string $consentVersion = null,
        ?Carbon $consentedAt = null,
    ): PaymentNotification {
        if ($amountKurus <= 0) {
            throw new GecersizTutarException('Bildirilen tutar sıfırdan büyük olmalıdır.');
        }
        if (! in_array($method, ['iban', 'elden'], true)) {
            throw new GecersizTutarException('Ödeme yolu IBAN/havale veya elden olmalıdır.');
        }

        $declaredOn ??= now();
        if ($declaredOn->isAfter(now()->endOfDay())) {
            throw new GecersizTutarException('Ödeme tarihi gelecekte olamaz.');
        }

        /** @var Tenant $tenant */
        $tenant = Tenant::on($this->connection)->findOrFail($tenantId);

        /** @var PaymentNotification $bildirim */
        $bildirim = PaymentNotification::on($this->connection)->create([
            'tenant_id' => $tenantId,
            'amount_kurus' => $amountKurus,
            'method' => $method,
            'reference_code' => $referenceCode !== null && trim($referenceCode) !== ''
                ? mb_strtoupper(trim($referenceCode))
                : self::referansUret($tenant->slug),
            'declared_on' => $declaredOn->toDateString(),
            'status' => PaymentNotification::STATUS_PENDING,
            'note' => $note,
            'consent_version' => $consentVersion,
            'consented_at' => $consentVersion !== null ? ($consentedAt ?? now()) : null,
        ]);

        return $bildirim;
    }

    /**
     * Havale açıklaması için referans kodu. Firma kodundan türer ki ekstrede gözle de eşleşsin;
     * sonundaki rastgele parça aynı bayinin iki bildirimini ayırır.
     */
    public static function referansUret(?string $tenantSlug): string
    {
        $taban = mb_strtoupper(substr((string) preg_replace('/[^a-z0-9]/', '', (string) $tenantSlug), 0, 8));
        if ($taban === '') {
            $taban = 'SIPARIO';
        }

        return $taban.'-'.mb_strtoupper(Str::random(4));
    }

    /**
     * Panelin bekleyen kutusu (en eski önce — beklemede kalan bildirim en acil olandır).
     *
     * @return Collection<int, PaymentNotification>
     */
    public function bekleyenler(int $limit = 200): Collection
    {
        return PaymentNotification::on($this->connection)
            ->where('status', PaymentNotification::STATUS_PENDING)
            ->orderBy('created_at')
            ->limit($limit)
            ->get();
    }

    /**
     * @return Collection<int, PaymentNotification>
     */
    public function bayiBildirimleri(string $tenantId, int $limit = 50): Collection
    {
        return PaymentNotification::on($this->connection)
            ->where('tenant_id', $tenantId)
            ->orderByDesc('created_at')
            ->limit($limit)
            ->get();
    }

    /**
     * EŞLEŞTİR — parayı gördük: gerçek ödeme kaydını yaratır, aboneliği uzatır, bildirimi kapatır.
     *
     * @param  int|null  $amountKurus  null → bayinin beyan ettiği tutar. Ekstredeki tutar farklıysa
     *                                 (eksik havale) GERÇEK tutar geçilir; kayıt beyanı değil parayı
     *                                 yansıtmalıdır.
     * @param  string  $coversPeriod  insan okunur dönem etiketi ("Ağustos 2026")
     */
    public function eslestir(
        string $bildirimId,
        string $coversPeriod,
        ?BillingPeriod $period = null,
        ?int $amountKurus = null,
        ?string $adminId = null,
    ): PaymentNotification {
        return $this->db()->transaction(function () use ($bildirimId, $coversPeriod, $period, $amountKurus, $adminId) {
            /** @var PaymentNotification $bildirim */
            $bildirim = PaymentNotification::on($this->connection)->lockForUpdate()->findOrFail($bildirimId);

            if ($bildirim->status !== PaymentNotification::STATUS_PENDING) {
                // Kapanmış bildirim yeniden işlenmez (durum makinesi tek yönlü). Sessiz geçiş:
                // ikinci tıklamaya hata göstermek yerine mevcut sonucu döndürmek doğru davranıştır.
                return $bildirim;
            }

            $sonuc = (new OdemeKayitServisi($this->connection))->kaydet(
                tenantId: $bildirim->tenant_id,
                amountKurus: $amountKurus ?? $bildirim->amount_kurus,
                method: $bildirim->method,
                coversPeriod: $coversPeriod,
                period: $period,
                note: $bildirim->note,
                adminId: $adminId,
                occurredAt: $bildirim->declared_on,
                // Kararlı idempotens anahtarı: aynı bildirim iki ödeme satırı doğuramaz.
                providerRef: 'notify:'.$bildirim->id,
            );

            $bildirim->forceFill([
                'status' => PaymentNotification::STATUS_MATCHED,
                'subscription_payment_id' => $sonuc['payment']->id,
                'resolved_at' => now(),
                'resolved_by_admin_id' => $adminId,
            ])->save();

            $this->denetle($adminId, $bildirim->tenant_id, 'payment_notification_match');

            return $bildirim;
        });
    }

    /** REDDET — para gelmemiş/eşleşmemiş. Ödeme kaydı OLUŞMAZ, abonelik değişmez. */
    public function reddet(string $bildirimId, ?string $adminId = null, ?string $note = null): PaymentNotification
    {
        /** @var PaymentNotification $bildirim */
        $bildirim = PaymentNotification::on($this->connection)->findOrFail($bildirimId);

        if ($bildirim->status !== PaymentNotification::STATUS_PENDING) {
            return $bildirim;
        }

        $bildirim->forceFill([
            'status' => PaymentNotification::STATUS_REJECTED,
            'resolved_at' => now(),
            'resolved_by_admin_id' => $adminId,
            'note' => $note ?? $bildirim->note,
        ])->save();

        $this->denetle($adminId, $bildirim->tenant_id, 'payment_notification_reject');

        return $bildirim;
    }
}
