<?php

namespace App\Abonelik;

use App\Enums\BillingPeriod;
use App\Models\Plan;

/**
 * Abonelik planının TEK OKUMA NOKTASI. Fiyat/deneme/kota artık `plans` tablosundan gelir;
 * `config/subscription.php` YALNIZ YEDEKtir.
 *
 * NEDEN YEDEK BIRAKILDI (config'i tamamen silmek yerine): plan satırı tek satırdır ve bir gün
 * migration'ı koşmamış bir ortamda ya da elle silinmiş bir kayıtta site FİYATSIZ kalırdı — checkout
 * "0 ₺" gösterip para almadan abonelik açardı. Yedek, sessiz sıfırdan iyidir. Yedeğin devreye
 * girdiği bir ortam ARIZALIdır ve bunu görmek için `plan()` null döndürür (çağıran isterse ayırt eder).
 *
 * ÖNBELLEK: `plan()` istek başına bir kez okur. Aynı istekte fiyat + deneme + kota sorulduğunda üç
 * ayrı sorgu atmanın anlamı yok; öte yandan süreç ömrü boyunca önbelleklemek (static) panelden
 * yapılan fiyat değişikliğini bir sonraki isteğe kadar geciktirirdi.
 */
class PlanDeposu extends AbonelikServisi
{
    private ?Plan $onbellek = null;

    private bool $okundu = false;

    /** Plan satırı; yoksa null (ARIZA — çağıranlar config yedeğine düşer). */
    public function plan(): ?Plan
    {
        if (! $this->okundu) {
            $this->onbellek = Plan::on($this->connection)->first();
            $this->okundu = true;
        }

        return $this->onbellek;
    }

    public function aylikKurus(): int
    {
        return $this->plan()->price_monthly_kurus ?? (int) config('subscription.price_monthly_kurus');
    }

    public function yillikKurus(): int
    {
        return $this->plan()->price_yearly_kurus ?? (int) config('subscription.price_yearly_kurus');
    }

    /** Seçili dönemin fiyatı — checkout ve elle ödeme kaydı bunu kullanır. */
    public function donemKurus(BillingPeriod $donem): int
    {
        return $donem === BillingPeriod::Monthly ? $this->aylikKurus() : $this->yillikKurus();
    }

    /** Deneme süresi (gün). BRIEF: 30 — tasarımdaki "14 gün" metinleri buna göre düzeltilir. */
    public function denemeGun(): int
    {
        return $this->plan()->trial_days ?? (int) config('subscription.trial_days');
    }

    /** Yeni bayinin aylık oto-sıralama kotası (tenants.route_credits_monthly tohumu). */
    public function rotaKontoruAylik(): int
    {
        return $this->plan()->route_credits_monthly ?? (int) config('subscription.route_credits_monthly');
    }

    /** Yeni bayinin kurye hesabı kotası (tenants.courier_limit tohumu). */
    public function kuryeLimiti(): int
    {
        return $this->plan()->courier_limit ?? (int) config('subscription.courier_limit');
    }

    /**
     * Planı güncelle (panelin "Planı Düzenle" modalı). GEÇMİŞE DOKUNMAZ: mevcut bayilerin
     * `route_credits_monthly` / `courier_limit` kolonları AYNEN KALIR. Tasarımın modal notu bunu
     * açıkça söylüyor ("geçmiş kayıtlar değişmez") ve tersi tehlikeli olurdu — bir fiyat
     * düzeltmesi, farkında olmadan yüzlerce bayinin kotasını düşürebilirdi.
     *
     * @param  array{name?: string, price_monthly_kurus?: int, price_yearly_kurus?: int, trial_days?: int, route_credits_monthly?: int, courier_limit?: int}  $veri
     */
    public function guncelle(array $veri, ?string $adminId = null): Plan
    {
        $plan = $this->plan();
        if ($plan === null) {
            // Satır yoksa yaratılır: tek satır kısıtı ikinciyi zaten reddeder.
            $plan = new Plan;
            $plan->setConnection($this->connection);
            $plan->forceFill([
                'name' => 'Sipario',
                'price_monthly_kurus' => (int) config('subscription.price_monthly_kurus'),
                'price_yearly_kurus' => (int) config('subscription.price_yearly_kurus'),
                'trial_days' => (int) config('subscription.trial_days'),
                'route_credits_monthly' => (int) config('subscription.route_credits_monthly'),
                'courier_limit' => (int) config('subscription.courier_limit'),
            ]);
        }

        foreach (['price_monthly_kurus', 'price_yearly_kurus', 'trial_days', 'route_credits_monthly', 'courier_limit'] as $alan) {
            if (isset($veri[$alan]) && (int) $veri[$alan] < 0) {
                throw new GecersizTutarException('Plan değerleri negatif olamaz.');
            }
        }

        $plan->fill(array_intersect_key($veri, array_flip([
            'name', 'price_monthly_kurus', 'price_yearly_kurus', 'trial_days',
            'route_credits_monthly', 'courier_limit',
        ])))->save();

        $this->onbellek = $plan;
        $this->okundu = true;

        // Denetim: hangi alanların dokunulduğu yazılır, YENİ DEĞERLER yazılmaz (nötr günlük kuralı).
        $this->denetle($adminId, null, 'plan_update', implode(',', array_keys($veri)));

        return $plan;
    }
}
