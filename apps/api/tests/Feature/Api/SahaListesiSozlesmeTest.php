<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\Order;
use App\Models\OrderLine;
use App\Models\TenantSetting;
use App\Support\Provisioning;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * 2026-11-05 SAHA LİSTESİNİN SUNUCU SÖZLEŞMESİ — satır iskontosu, müşteriye özel fiyat, gider
 * kategorileri (API 1.29.0, mobil 1.15.0).
 *
 * Üçünde de ortak tehlike "sunucuda doğru duran ama inmeyen alan" ve "alanı bilmeyen eski build'in
 * değeri silmesi"dir; bu yüzden her alan için ikisi de ayrıca kilitlidir.
 */
class SahaListesiSozlesmeTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /** @return array<string, mixed> */
    private function siparisOlayi(string $siparisId, array $satir): array
    {
        return $this->orderCreated([$satir], ['id' => $siparisId, 'customer_id' => null]);
    }

    /** @return array<string, mixed> */
    private function satir(array $ek = []): array
    {
        return [
            'id' => (string) Str::uuid7(),
            'product_name' => 'Damacana',
            'unit_price_kurus' => 10000,
            'qty' => 3,
            'is_custom' => true,
        ] + $ek;
    }

    #[Test]
    public function satir_iskontosu_satir_ve_siparis_toplamindan_duser(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $siparisId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $this->siparisOlayi($siparisId, $this->satir(['discount_kurus' => 2500])),
        ])->assertJsonPath('results.0.status', 'applied');

        $satir = Provisioning::asOwner(fn () => OrderLine::query()->where('order_id', $siparisId)->first());
        $this->assertNotNull($satir);
        $this->assertSame(2500, $satir->discount_kurus);
        $this->assertSame(27500, $satir->line_total_kurus);

        $siparis = Provisioning::asOwner(fn () => Order::query()->find($siparisId));
        $this->assertSame(27500, $siparis->total_kurus);

        $snapshot = $this->pullSince($token, 0);
        $inen = collect($snapshot->json('entities.order_line'))->firstWhere('order_id', $siparisId);
        $this->assertSame(2500, $inen['discount_kurus'] ?? null, 'İskonto snapshot yolundan inmiyor.');
    }

    #[Test]
    public function iskonto_gondermeyen_eski_istemcinin_toplami_degismez(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $siparisId = (string) Str::uuid7();

        $this->pushEvents($token, [$this->siparisOlayi($siparisId, $this->satir())])
            ->assertJsonPath('results.0.status', 'applied');

        $satir = Provisioning::asOwner(fn () => OrderLine::query()->where('order_id', $siparisId)->first());
        $this->assertSame(0, $satir->discount_kurus);
        $this->assertSame(30000, $satir->line_total_kurus);
    }

    #[Test]
    public function satir_tutarini_asan_ya_da_negatif_iskonto_reddedilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        foreach ([30001, -1] as $iskonto) {
            $this->pushEvents($token, [
                $this->siparisOlayi((string) Str::uuid7(), $this->satir(['discount_kurus' => $iskonto])),
            ])->assertJsonPath('results.0.status', 'rejected');
        }
    }

    #[Test]
    public function musteri_fiyati_yazilir_iner_ve_ad_duzeltmesinde_korunur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $musteriId = (string) Str::uuid7();
        $urunId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $this->event('customer', 'upsert', [
                'id' => $musteriId,
                'name' => 'Ayşe',
                'product_prices' => [$urunId => 8500],
            ]),
        ])->assertJsonPath('results.0.status', 'applied');

        $snapshot = $this->pullSince($token, 0);
        $inen = collect($snapshot->json('entities.customer'))->firstWhere('id', $musteriId);
        $this->assertIsArray($inen['product_prices'] ?? null, 'Fiyatlar snapshot yolundan inmiyor.');
        $this->assertSame(8500, $inen['product_prices'][$urunId]);

        // Alanı bilmeyen eski build adı düzeltiyor: anahtar payload'da yok, fiyat silinmemeli.
        $this->pushEvents($token, [
            $this->event('customer', 'upsert', ['id' => $musteriId, 'name' => 'Ayşe Yılmaz']),
        ])->assertJsonPath('results.0.status', 'applied');

        $musteri = Provisioning::asOwner(fn () => Customer::query()->find($musteriId));
        $this->assertSame('Ayşe Yılmaz', $musteri->name);
        $this->assertSame(8500, $musteri->product_prices[$urunId] ?? null);
    }

    #[Test]
    public function bozuk_musteri_fiyatlari_reddedilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        foreach ([['x'], ['urun' => -1], ['urun' => '100'], 'metin'] as $bozuk) {
            $this->pushEvents($token, [
                $this->event('customer', 'upsert', [
                    'id' => (string) Str::uuid7(),
                    'name' => 'Bozuk',
                    'product_prices' => $bozuk,
                ]),
            ])->assertJsonPath('results.0.status', 'rejected');
        }
    }

    #[Test]
    public function gider_kategorileri_yazilir_iner_ve_baska_ayar_yaziminda_korunur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [
            $this->event('tenant_settings', 'upsert', [
                'business_name' => 'Bayi',
                'expense_categories' => ['Yakıt', 'Kömür', 'Yakıt'],
            ]),
        ])->assertJsonPath('results.0.status', 'applied');

        $snapshot = $this->pullSince($token, 0);
        $inen = collect($snapshot->json('entities.tenant_settings'))->first();
        $this->assertSame(['Yakıt', 'Kömür'], $inen['expense_categories'] ?? null);

        // Alanı bilmeyen eski build profil yazıyor: kategoriler silinmemeli.
        $this->pushEvents($token, [
            $this->event('tenant_settings', 'upsert', ['business_name' => 'Yeni Ad']),
        ])->assertJsonPath('results.0.status', 'applied');

        $ayar = Provisioning::asOwner(fn () => TenantSetting::query()->find($a['tenant']->id));
        $this->assertSame('Yeni Ad', $ayar->business_name);
        $this->assertSame(['Yakıt', 'Kömür'], $ayar->expense_categories);
    }

    #[Test]
    public function bozuk_gider_kategorileri_reddedilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        foreach ([['a' => 'b'], [1], [str_repeat('x', 41)], 'metin'] as $bozuk) {
            $this->pushEvents($token, [
                $this->event('tenant_settings', 'upsert', ['expense_categories' => $bozuk]),
            ])->assertJsonPath('results.0.status', 'rejected');
        }
    }
}
