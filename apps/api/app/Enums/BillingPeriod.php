<?php

namespace App\Enums;

use Illuminate\Support\Carbon;

/**
 * Abonelik dönemi (OKU-BENI.md kararı: "aylık + yıllık"; BRIEF'teki "yalnız yıllık" AŞILDI).
 * Değerler `tenants.billing_period` ve `subscription_payments.period` CHECK kısıtlarıyla aynıdır.
 *
 * `subscription_payments.period` ayrıca 'addon' değerini alabilir — o bir ABONELİK dönemi değil,
 * ek paket geliridir ve aboneliği uzatmaz; bu yüzden bilinçli olarak bu enum'a KONMADI. Enum'a
 * konsaydı `uzat()` çağrılabilir hâle gelir ve bir ek paket satışı sessizce abonelik uzatırdı.
 */
enum BillingPeriod: string
{
    case Monthly = 'monthly';
    case Yearly = 'yearly';

    /**
     * Dönem sonunu hesaplar. TABAN GEÇMİŞTE OLAMAZ kuralı burada DEĞİL çağıranda durur
     * (OdemeKayitServisi): erken ödeyen bayinin kalan günleri yanmasın diye taban
     * `valid_until > now ? valid_until : now`tir.
     *
     * addMonth/addYear takvim bazlıdır (31 Ocak + 1 ay = 28/29 Şubat). Gün sayısıyla (+30/+365)
     * hesaplamak, "her ayın 3'ünde öderim" diyen bayide bitişi her ay 2-3 gün kaydırırdı.
     */
    public function uzat(Carbon $taban): Carbon
    {
        return match ($this) {
            self::Monthly => $taban->copy()->addMonthNoOverflow(),
            self::Yearly => $taban->copy()->addYear(),
        };
    }

    /** Panelde/sitede gösterilecek Türkçe etiket. */
    public function etiket(): string
    {
        return match ($this) {
            self::Monthly => 'Aylık',
            self::Yearly => 'Yıllık',
        };
    }
}
