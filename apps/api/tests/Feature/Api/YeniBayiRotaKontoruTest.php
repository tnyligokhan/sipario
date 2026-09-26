<?php

namespace Tests\Feature\Api;

use App\Abonelik\EkPaketServisi;
use App\Models\AddonPackage;
use App\Models\Tenant;
use App\Support\Provisioning;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * YENİ BAYİNİN OTO-SIRALAMA HAKKI (saha şikâyeti 2026-09-26: "Yeni açılan üyeye Oto-Sıralama
 * hakkı tanımlaması yapmıyor").
 *
 * Açılış yalnız AYLIK KOTAYI yazıyordu; KALAN HAK 0'da kalıyordu. Mobil sayaç 0 olduğu için
 * "Oto Sırala" düğmesini hiç çizmiyor, sunucu da 409 veriyordu. İki şey kilitlenir: açılış hakkı
 * verir, onarım göçü yalnız hiç hak almamış bayiye dokunur.
 */
class YeniBayiRotaKontoruTest extends ApiTestCase
{
    private const GOC = '2026_09_26_000101_seed_missing_route_credits.php';

    #[Test]
    public function yeni_bayi_aylik_kota_kadar_hakla_acilir(): void
    {
        $sonuc = Provisioning::createTenantWithPatron(
            'Hakli Su', 'hakli@sipario.test', 'password123', 'Hakli Patron'
        );

        $bayi = $this->taze($sonuc['tenant']->id);
        $this->assertGreaterThan(0, $bayi->route_credits_monthly);
        $this->assertSame($bayi->route_credits_monthly, $bayi->route_credits,
            'kalan hak aylık kotayla başlamalı — 0 kalırsa özellik hiç görünmez');
    }

    #[Test]
    public function onarim_gocu_hic_hak_almamis_bayiyi_onarir(): void
    {
        ['tenant' => $bayi] = $this->makeTenant('hakyok');
        $this->hakYaz($bayi->id, 0);

        $this->gocuKos();

        $taze = $this->taze($bayi->id);
        $this->assertSame($taze->route_credits_monthly, $taze->route_credits);
    }

    #[Test]
    public function onarim_gocu_kontor_paketi_almis_bayiye_dokunmaz(): void
    {
        // Paket almış bayinin sıfırı GERÇEK bir tüketim olabilir; onu doldurmak bedava hak
        // dağıtmak olurdu.
        ['tenant' => $bayi] = $this->makeTenant('hakbitti');
        $paket = $this->asOwner(fn () => AddonPackage::on('pgsql_owner')
            ->where('type', 'credits')->firstOrFail());
        (new EkPaketServisi('pgsql_owner'))->tanimla($bayi->id, $paket->id, 'iban');
        $this->hakYaz($bayi->id, 0);

        $this->gocuKos();

        $this->assertSame(0, $this->taze($bayi->id)->route_credits);
    }

    #[Test]
    public function onarim_gocu_hakki_olan_bayiye_dokunmaz(): void
    {
        ['tenant' => $bayi] = $this->makeTenant('hakvar');
        $this->hakYaz($bayi->id, 7);

        $this->gocuKos();

        $this->assertSame(7, $this->taze($bayi->id)->route_credits);
    }

    // ── Yardımcılar ──────────────────────────────────────────────────────────

    private function gocuKos(): void
    {
        $goc = require database_path('migrations/'.self::GOC);
        $this->asOwner(fn () => $goc->up());
    }

    private function hakYaz(string $tenantId, int $adet): void
    {
        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenantId)
            ->update(['route_credits' => $adet]));
    }

    private function taze(string $tenantId): Tenant
    {
        /** @var Tenant $tenant */
        $tenant = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($tenantId));

        return $tenant;
    }
}
