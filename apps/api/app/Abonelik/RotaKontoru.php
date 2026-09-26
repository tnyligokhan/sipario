<?php

namespace App\Abonelik;

use App\Enums\TenantStatus;
use App\Models\Tenant;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * OTO-SIRALAMA KONTÖRÜNÜN TEK KURALI — yenileme, harcama, satın alma (2026-09-26).
 *
 * İki kaynak vardır ve `tenants.route_credits` ikisinin TOPLAMIDIR (mobil yalnız toplamı görür):
 *  • ÜCRETSİZ AYLIK HAK — her ayın 1'inde (İstanbul) `route_credits_monthly` kadar yenilenir,
 *    kullanılmayanı DEVRETMEZ (kullanım koşulları md. "aylık kontör … devretmez").
 *  • SATIN ALINAN HAK — `route_credits_purchased`; süresi dolmaz, aydan aya devreder.
 *
 * HARCAMADA ÖNCE ÜCRETSİZ HAK DÜŞER. Aksi, bayinin parasıyla aldığı hakkı ay sonunda zaten
 * silinecek ücretsiz hakkın yerine yakmak olurdu. Bu yüzden satın alınan kısım yalnız toplam onun
 * altına inince azalır: purchased = min(purchased, total).
 *
 * DENEME YENİLENMEZ: sitede denemenin hakkı "deneme boyunca geçerli" diye yazıyor. Deneme
 * bayisi açılışta aylık kota kadar hak alır; ücretli üyeliğe geçtikten sonraki ilk ay başında
 * yenileme başlar.
 *
 * YENİLEME İDEMPOTENTTİR: `route_credits_renewed_on` son yenilemenin dönem başıdır ve UPDATE
 * yalnız o tarih bu aydan eskiyse satır bulur. Günlük iş, oto-sıralama isteği ve senkron aynı
 * kuralı üst üste çağırabilir; ay başına en fazla bir kez etki eder.
 */
final class RotaKontoru
{
    private const SAAT_DILIMI = 'Europe/Istanbul';

    public function __construct(private readonly ?string $baglanti = null) {}

    /** İçinde bulunulan dönemin başı (ayın 1'i, İstanbul) — `Y-m-d`. */
    public static function donemBasi(?CarbonImmutable $an = null): string
    {
        return ($an ?? CarbonImmutable::now(self::SAAT_DILIMI))
            ->setTimezone(self::SAAT_DILIMI)
            ->startOfMonth()
            ->toDateString();
    }

    /**
     * Yenileme zamanı gelmiş bayilerin ücretsiz hakkını yeniler. [$tenantId] verilirse yalnız o
     * bayi. Etkilenen bayi sayısını döndürür.
     */
    public function yenile(?string $tenantId = null, ?CarbonImmutable $an = null): int
    {
        $donem = self::donemBasi($an);
        $sql = 'UPDATE tenants SET route_credits = route_credits_purchased + route_credits_monthly, '.
            'route_credits_renewed_on = ? '.
            'WHERE status <> ? AND (route_credits_renewed_on IS NULL OR route_credits_renewed_on < ?)';
        $degerler = [$donem, TenantStatus::Trial->value, $donem];
        if ($tenantId !== null) {
            $sql .= ' AND id = ?';
            $degerler[] = $tenantId;
        }

        return DB::connection($this->baglanti)->update($sql, $degerler);
    }

    /**
     * Bir hak harca — çağıran satırı KİLİTLEMİŞ olmalıdır (FOR UPDATE). Önce ücretsiz hak düşer.
     */
    public function harca(Tenant $kilitli): void
    {
        $kalan = $kilitli->route_credits - 1;
        $kilitli->forceFill([
            'route_credits' => $kalan,
            'route_credits_purchased' => max(0, min($kilitli->route_credits_purchased, $kalan)),
        ])->save();
    }

    /** Satın alınan paketi ekler — toplam da satın alınan kısım da artar. */
    public function satinAlindi(Tenant $tenant, int $adet): void
    {
        $tenant->forceFill([
            'route_credits' => $tenant->route_credits + $adet,
            'route_credits_purchased' => $tenant->route_credits_purchased + $adet,
        ])->save();
    }
}
