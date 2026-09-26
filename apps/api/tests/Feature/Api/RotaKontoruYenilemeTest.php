<?php

namespace Tests\Feature\Api;

use App\Abonelik\EkPaketServisi;
use App\Abonelik\RotaKontoru;
use App\Enums\TenantStatus;
use App\Models\AddonPackage;
use App\Models\Tenant;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Artisan;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsRouteStops;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * OTO-SIRALAMA HAKKININ AYLIK YENİLENMESİ (kullanıcı kararı 2026-09-26: "her ay ücretsiz bir
 * şekilde belli bir hak veriyor olmamız gerekiyordu; ay içinde bitirirse satın alabilir").
 *
 * Kilitlenen sözleşme (kullanım koşulları ve sitenin vaadi): ücretsiz hak her ay başı
 * yenilenir ve DEVRETMEZ; satın alınan hak SİLİNMEZ ve devreder; harcamada önce ücretsiz hak
 * düşer; deneme yenilenmez; yenileme ay başına bir kez etki eder.
 */
class RotaKontoruYenilemeTest extends ApiTestCase
{
    use BuildsRouteStops;
    use BuildsSyncEvents;

    private const LARA = [36.8632, 30.7809];

    #[Test]
    public function kullanilmayan_ucretsiz_hak_devretmez(): void
    {
        $id = $this->bayi(kalan: 12, satinAlinan: 0, aylik: 50, oncekiAy: true);

        $this->assertSame(1, (new RotaKontoru('pgsql_owner'))->yenile());

        $this->assertSame(50, $this->taze($id)->route_credits, 'yenileme 12 + 50 değil, 50 verir');
        $this->assertSame(RotaKontoru::donemBasi(), $this->taze($id)->route_credits_renewed_on?->toDateString());
    }

    #[Test]
    public function satin_alinan_hak_yenilemede_korunur(): void
    {
        // 260 kalan: 10'u bu ayın ücretsiz artığı, 250'si satın alınmış.
        $id = $this->bayi(kalan: 260, satinAlinan: 250, aylik: 50, oncekiAy: true);

        (new RotaKontoru('pgsql_owner'))->yenile();

        $this->assertSame(300, $this->taze($id)->route_credits, '250 satın alınan + 50 yeni ücretsiz');
        $this->assertSame(250, $this->taze($id)->route_credits_purchased);
    }

    #[Test]
    public function ayni_ay_ikinci_yenileme_etkisizdir(): void
    {
        $id = $this->bayi(kalan: 0, satinAlinan: 0, aylik: 50, oncekiAy: true);
        $kontor = new RotaKontoru('pgsql_owner');

        $kontor->yenile();
        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($id)->update(['route_credits' => 7]));

        $this->assertSame(0, $kontor->yenile(), 'aynı ay içinde ikinci kez hak dağıtılmaz');
        $this->assertSame(7, $this->taze($id)->route_credits);
    }

    #[Test]
    public function yeni_ay_gelince_yeniden_yenilenir(): void
    {
        $id = $this->bayi(kalan: 3, satinAlinan: 0, aylik: 50, oncekiAy: false);
        $gelecekAy = CarbonImmutable::now('Europe/Istanbul')->addMonthNoOverflow()->startOfMonth()->addHours(1);

        $this->assertSame(0, (new RotaKontoru('pgsql_owner'))->yenile(an: CarbonImmutable::now()));
        $this->assertSame(1, (new RotaKontoru('pgsql_owner'))->yenile(an: $gelecekAy));
        $this->assertSame(50, $this->taze($id)->route_credits);
    }

    #[Test]
    public function deneme_bayisi_yenilenmez(): void
    {
        // Site: denemenin hakkı "deneme boyunca geçerli".
        $id = $this->bayi(kalan: 0, satinAlinan: 0, aylik: 50, oncekiAy: true, deneme: true);

        (new RotaKontoru('pgsql_owner'))->yenile();

        $this->assertSame(0, $this->taze($id)->route_credits);
    }

    #[Test]
    public function harcamada_once_ucretsiz_hak_duser(): void
    {
        $id = $this->bayi(kalan: 12, satinAlinan: 10, aylik: 50, oncekiAy: false);
        $kontor = new RotaKontoru('pgsql_owner');

        $this->asOwner(function () use ($id, $kontor) {
            $kontor->harca(Tenant::on('pgsql_owner')->findOrFail($id)); // 12 → 11, satın alınan 10
            $kontor->harca(Tenant::on('pgsql_owner')->findOrFail($id)); // 11 → 10, satın alınan 10
            $kontor->harca(Tenant::on('pgsql_owner')->findOrFail($id)); // 10 → 9, satın alınan 9
        });

        $this->assertSame(9, $this->taze($id)->route_credits);
        $this->assertSame(9, $this->taze($id)->route_credits_purchased,
            'ücretsiz hak bitene dek satın alınan hakka dokunulmaz');
    }

    #[Test]
    public function kontor_paketi_satin_alinan_hak_olarak_islenir(): void
    {
        ['tenant' => $bayi] = $this->makeTenant('paketli');
        $paket = $this->asOwner(fn () => AddonPackage::on('pgsql_owner')
            ->where('type', 'credits')->firstOrFail());
        $once = $this->taze($bayi->id);

        (new EkPaketServisi('pgsql_owner'))->tanimla($bayi->id, $paket->id, 'iban');

        $sonra = $this->taze($bayi->id);
        $this->assertSame($once->route_credits + $paket->quantity, $sonra->route_credits);
        $this->assertSame($once->route_credits_purchased + $paket->quantity, $sonra->route_credits_purchased);
    }

    #[Test]
    public function zamanlanmis_komut_yeniler(): void
    {
        $id = $this->bayi(kalan: 0, satinAlinan: 0, aylik: 40, oncekiAy: true);

        Artisan::call('rota:aylik-yenile');

        $this->assertSame(40, $this->taze($id)->route_credits);
    }

    #[Test]
    public function oto_siralama_istegi_ay_basi_yenilemesini_kendisi_de_yapar(): void
    {
        // Zamanlayıcı aksasa bile hakkı yenilenmiş bayi "hakkınız kalmadı" görmemeli.
        $a = $this->makeTenant('istek');
        $this->bayiGuncelle($a['tenant']->id, kalan: 0, satinAlinan: 0, aylik: 5, oncekiAy: true);
        $token = $this->tokenFor($a['patron']);
        $siparisler = $this->siparisleriKur($token, ['lara' => self::LARA]);

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => array_values($siparisler),
        ]);

        $yanit->assertOk();
        $this->assertSame(4, $yanit->json('route_credits'), 'yenilenen 5 hakkın biri harcandı');
    }

    // ── Yardımcılar ──────────────────────────────────────────────────────────

    private function bayi(int $kalan, int $satinAlinan, int $aylik, bool $oncekiAy, bool $deneme = false): string
    {
        static $sira = 0;
        $sira++;
        ['tenant' => $t] = $this->makeTenant('kontor'.$sira);
        $this->bayiGuncelle($t->id, $kalan, $satinAlinan, $aylik, $oncekiAy, $deneme);

        return $t->id;
    }

    private function bayiGuncelle(
        string $id,
        int $kalan,
        int $satinAlinan,
        int $aylik,
        bool $oncekiAy,
        bool $deneme = false,
    ): void {
        $donem = CarbonImmutable::parse(RotaKontoru::donemBasi());
        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($id)->update([
            'route_credits' => $kalan,
            'route_credits_purchased' => $satinAlinan,
            'route_credits_monthly' => $aylik,
            'route_credits_renewed_on' => ($oncekiAy ? $donem->subMonthNoOverflow() : $donem)->toDateString(),
            'status' => $deneme ? TenantStatus::Trial->value : TenantStatus::Active->value,
        ]));
    }

    private function taze(string $tenantId): Tenant
    {
        /** @var Tenant $tenant */
        $tenant = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($tenantId));

        return $tenant;
    }
}
