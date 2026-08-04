<?php

namespace App\Abonelik;

use App\Models\AddonGrant;
use App\Models\AddonPackage;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * EK PAKET KATALOĞU + FİRMAYA TANIMLAMA.
 *
 * Tanımlamanın tamamı TEK TRANSACTION'dır ve üç şey birlikte olur:
 *   1. `addon_grants` satırı (append-only kayıt — ne verdik, kime, hangi tahsilatla)
 *   2. bedelsiz DEĞİLSE `subscription_payments` satırı (`period='addon'`) — gelir raporu tek
 *      tablodan okunsun diye (bkz. migration 005009)
 *   3. bayinin KOTASI: credits → `tenants.route_credits` += adet, courier → `tenants.courier_limit`
 *      += adet
 * Üçü ayrışırsa ortaya "parası alınmış ama hakkı gelmemiş" bayi çıkar; sahada bunun telafisi yoktur.
 *
 * ABONELİK BİTİŞİ DEĞİŞMEZ (tasarımın modal notu: "abonelik bitişi değişmez"). Ek paket bir SÜRE
 * değil KAPASİTE satışıdır; `valid_until`a dokunmak sessizce bedava abonelik dağıtmak olurdu.
 *
 * KOTA ARTIŞI KALICIDIR (aylık sıfırlanmaz): satın alınan 250 hak, aylık kotanın ÜSTÜNE eklenen
 * bakiyedir. Aylık kota (`route_credits_monthly`) yenileme miktarıdır ve plan tarafından belirlenir;
 * satın alınan hakları her ay yenilemek onları abonelik kapsamına sokardı.
 */
class EkPaketServisi extends AbonelikServisi
{
    /**
     * Katalog. $yalnizAktif=true → yalnız satıştakiler (tanımlama modalı bunu kullanır).
     *
     * @return Collection<int, AddonPackage>
     */
    public function paketler(bool $yalnizAktif = false): Collection
    {
        $q = AddonPackage::on($this->connection)->orderBy('type')->orderBy('quantity');

        if ($yalnizAktif) {
            $q->where('active', true);
        }

        return $q->get();
    }

    /**
     * Paket ekle/düzenle. `id` verilirse düzenleme; verilmiş ama bulunamıyorsa HATA (PanelWriteService
     * kuralı: düzenleme akışı upsert değildir — sessizce kopya paket yaratmak katalogu kirletir).
     *
     * @param  array{id?: string|null, type: string, name: string, quantity: int, price_kurus: int, active?: bool}  $veri
     */
    public function paketKaydet(array $veri, ?string $adminId = null): AddonPackage
    {
        $tur = $veri['type'];
        if (! in_array($tur, [AddonPackage::TYPE_CREDITS, AddonPackage::TYPE_COURIER], true)) {
            throw new GecersizTutarException('Paket türü geçersiz.');
        }
        $ad = trim($veri['name']);
        if ($ad === '') {
            throw new GecersizTutarException('Paket adı zorunludur.');
        }
        if ((int) $veri['quantity'] <= 0) {
            throw new GecersizTutarException('Paket kapsamı sıfırdan büyük olmalıdır.');
        }
        if ((int) $veri['price_kurus'] < 0) {
            throw new GecersizTutarException('Paket ücreti negatif olamaz.');
        }

        $istenen = $veri['id'] ?? null;
        $paket = $istenen !== null ? AddonPackage::on($this->connection)->find($istenen) : null;
        if ($istenen !== null && $paket === null) {
            throw new GecersizTutarException('Düzenlenecek paket bulunamadı; sayfayı tazeleyip tekrar deneyin.');
        }

        if ($paket === null) {
            $paket = new AddonPackage;
            $paket->setConnection($this->connection);
        }

        $paket->fill([
            'type' => $tur,
            'name' => $ad,
            'quantity' => (int) $veri['quantity'],
            'price_kurus' => (int) $veri['price_kurus'],
            'active' => $veri['active'] ?? $paket->active ?? true,
        ])->save();

        $this->denetle($adminId, null, $istenen !== null ? 'addon_package_update' : 'addon_package_create', 'package:'.$paket->id);

        return $paket;
    }

    /** Paketi satıştan çek / geri koy. SİLME YOKtur — geçmiş tanımlamalar referanslıdır. */
    public function paketAktiflik(string $paketId, bool $aktif, ?string $adminId = null): AddonPackage
    {
        /** @var AddonPackage $paket */
        $paket = AddonPackage::on($this->connection)->findOrFail($paketId);
        $paket->forceFill(['active' => $aktif])->save();

        $this->denetle($adminId, null, $aktif ? 'addon_package_activate' : 'addon_package_deactivate', 'package:'.$paketId);

        return $paket;
    }

    /**
     * FİRMAYA TANIMLA — paketi bayinin hesabına işler, kotayı büyütür, (bedelsiz değilse) gelir yazar.
     *
     * @param  string  $collectionMethod  'iban' | 'elden' | 'bedelsiz'
     * @param  int|null  $amountKurus  null → paketin liste fiyatı. 'bedelsiz' ise HER HÂLDE 0
     *                                 (DB CHECK de bunu zorlar; tasarımda tutar alanı pasifleşir).
     */
    public function tanimla(
        string $tenantId,
        string $paketId,
        string $collectionMethod,
        ?int $amountKurus = null,
        ?Carbon $grantedOn = null,
        ?string $note = null,
        ?string $adminId = null,
    ): AddonGrant {
        if (! in_array($collectionMethod, ['iban', 'elden', 'bedelsiz'], true)) {
            throw new GecersizTutarException('Tahsilat yolu IBAN, elden veya bedelsiz olmalıdır.');
        }

        $grantedOn ??= now();

        return $this->db()->transaction(function () use ($tenantId, $paketId, $collectionMethod, $amountKurus, $grantedOn, $note, $adminId) {
            /** @var AddonPackage $paket */
            $paket = AddonPackage::on($this->connection)->findOrFail($paketId);
            /** @var Tenant $tenant */
            $tenant = Tenant::on($this->connection)->lockForUpdate()->findOrFail($tenantId);

            $tutar = $collectionMethod === 'bedelsiz' ? 0 : ($amountKurus ?? $paket->price_kurus);
            if ($tutar < 0) {
                throw new GecersizTutarException('Tanımlama tutarı negatif olamaz.');
            }

            $grantId = (string) Str::uuid7();

            /** @var AddonGrant $grant */
            $grant = AddonGrant::on($this->connection)->create([
                'id' => $grantId,
                'tenant_id' => $tenantId,
                'addon_package_id' => $paket->id,
                // Ad/tür/adet KOPYALANIR: paket bağı kopsa bile kayıt kendini anlatsın.
                'package_name' => $paket->name,
                'type' => $paket->type,
                'quantity' => $paket->quantity,
                'amount_kurus' => $tutar,
                'collection_method' => $collectionMethod,
                'granted_on' => $grantedOn->toDateString(),
                'note' => $note,
                'admin_user_id' => $adminId,
            ]);

            if ($tutar > 0) {
                SubscriptionPayment::on($this->connection)->create([
                    'tenant_id' => $tenantId,
                    'amount_kurus' => $tutar,
                    'currency' => (string) config('subscription.currency'),
                    'provider' => $collectionMethod,   // iban | elden
                    // Tanımlama id'si idempotens anahtarıdır: aynı grant iki gelir satırı doğuramaz.
                    'provider_ref' => 'grant:'.$grantId,
                    'status' => 'success',
                    'period' => SubscriptionPayment::PERIOD_ADDON,
                    'covers_period' => 'Ek paket · '.$paket->name,
                    'note' => $note,
                    'recorded_by_admin_id' => $adminId,
                    'consent_version' => null,
                    'consented_at' => null,
                    'occurred_at' => $grantedOn,
                ]);
            }

            // KOTA: sunucuda gerçek olan kısım. Ham SQL increment değil forceFill — kolon adı
            // türe göre değiştiği için tek yerde toplanıyor ve yanlış kolona yazma ihtimali kalmıyor.
            $kolon = $paket->type === AddonPackage::TYPE_CREDITS ? 'route_credits' : 'courier_limit';
            $tenant->forceFill([$kolon => $tenant->{$kolon} + $paket->quantity])->save();

            $this->denetle($adminId, $tenantId, 'addon_grant', $paket->type.':'.$collectionMethod);

            return $grant;
        });
    }

    /**
     * Tanımlama geçmişi. $tenantId verilirse tek bayi, verilmezse tüm liste (panelin "Son
     * Tanımlamalar" kartı).
     *
     * @return Collection<int, AddonGrant>
     */
    public function tanimlamalar(?string $tenantId = null, int $limit = 200): Collection
    {
        $q = AddonGrant::on($this->connection)
            ->orderByDesc('granted_on')->orderByDesc('created_at')->limit($limit);

        if ($tenantId !== null) {
            $q->where('tenant_id', $tenantId);
        }

        return $q->get();
    }
}
