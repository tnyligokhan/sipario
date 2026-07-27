<?php

namespace Tests\Feature\Api;

use App\Models\Tenant;
use App\Support\Provisioning;
use App\Support\Route\RouteOrderer;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * "Oto Sırala (rota)" — tasarım `s-siparisler.jsx` sıralama sayfasındaki kontörlü eylem.
 *
 * Sınananlar: sıra doğru mu, kontör düşüyor mu, kontörsüz ne oluyor, boş işlem kontör yakıyor
 * mu, başka bayinin siparişi sızıyor mu, uç nokta siparişlere YAZIYOR mu (yazmamalı).
 */
class AutoRouteTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /** Antalya'da gerçekçi koordinatlar; aralarındaki sıralama gözle de doğrulanabilir. */
    private const KEPEZ = [36.9125, 30.6689];

    private const MURATPASA = [36.8841, 30.7056];

    private const LARA = [36.8632, 30.7809];

    #[Test]
    public function en_yakin_komsu_zinciri_ilk_duragi_koruyarak_siralar(): void
    {
        // Saf birim testi: Lara'dan başlarsak sıra Lara → Muratpaşa → Kepez olmalı
        // (Muratpaşa ikisinin ortasında; Lara'ya Kepez'den daha yakın).
        $sonuc = RouteOrderer::sirala([
            ['id' => 'lara', 'lat' => self::LARA[0], 'lng' => self::LARA[1]],
            ['id' => 'kepez', 'lat' => self::KEPEZ[0], 'lng' => self::KEPEZ[1]],
            ['id' => 'muratpasa', 'lat' => self::MURATPASA[0], 'lng' => self::MURATPASA[1]],
        ]);

        $this->assertSame(['lara', 'muratpasa', 'kepez'], $sonuc['order']);
        $this->assertSame(0, $sonuc['without_location']);
    }

    #[Test]
    public function konumsuz_duraklar_goreli_sirayla_sona_atilir(): void
    {
        // Koordinatı olmayan sipariş rotaya giremez ama KAYBOLMAZ: sona, aralarındaki sırayı
        // koruyarak eklenir ve sayısı çağırana bildirilir (UI kullanıcıya söyler).
        $sonuc = RouteOrderer::sirala([
            ['id' => 'konumsuz-1', 'lat' => null, 'lng' => null],
            ['id' => 'lara', 'lat' => self::LARA[0], 'lng' => self::LARA[1]],
            ['id' => 'konumsuz-2', 'lat' => 36.9, 'lng' => null],
            ['id' => 'kepez', 'lat' => self::KEPEZ[0], 'lng' => self::KEPEZ[1]],
        ]);

        $this->assertSame(['lara', 'kepez', 'konumsuz-1', 'konumsuz-2'], $sonuc['order']);
        $this->assertSame(2, $sonuc['without_location']);
    }

    #[Test]
    public function uc_nokta_sirayi_doner_ve_kontoru_bir_dusurur(): void
    {
        $a = $this->makeTenant('a');
        $this->setRouteCredits($a['tenant']->id, 34);
        $token = $this->tokenFor($a['patron']);

        $siparisler = $this->siparisleriKur($token, [
            'lara' => self::LARA,
            'kepez' => self::KEPEZ,
            'muratpasa' => self::MURATPASA,
        ]);

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$siparisler['lara'], $siparisler['kepez'], $siparisler['muratpasa']],
        ]);

        $yanit->assertOk();
        $this->assertSame(
            [$siparisler['lara'], $siparisler['muratpasa'], $siparisler['kepez']],
            $yanit->json('order'),
        );
        $this->assertSame(0, $yanit->json('without_location'));
        $this->assertSame(33, $yanit->json('route_credits'), 'bir hak düşer');
        $this->assertSame(33, $this->routeCredits($a['tenant']->id));
    }

    #[Test]
    public function uc_nokta_siparislere_yazmaz_sadece_sira_onerir(): void
    {
        // Kırmızı çizgi: tek yazma yüzeyi sync push'tur. Bu uç nokta bir ÖNERİ döner;
        // sıra `sort_set` olayıyla istemciden gelir, yoksa offline/LWW semantiği bozulurdu.
        $a = $this->makeTenant('a');
        $this->setRouteCredits($a['tenant']->id, 5);
        $token = $this->tokenFor($a['patron']);
        $siparisler = $this->siparisleriKur($token, ['lara' => self::LARA, 'kepez' => self::KEPEZ]);

        $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => array_values($siparisler),
        ])->assertOk();

        $sortIndexler = $this->asOwner(
            fn () => DB::table('orders')
                ->whereIn('id', array_values($siparisler))
                ->pluck('sort_index')
                ->all()
        );
        $this->assertSame([null, null], $sortIndexler, 'uç nokta orders tablosuna dokunmaz');
    }

    #[Test]
    public function kontor_bittiginde_409_doner_ve_eksiye_dusmez(): void
    {
        $a = $this->makeTenant('a');
        $this->setRouteCredits($a['tenant']->id, 0);
        $token = $this->tokenFor($a['patron']);
        $siparisler = $this->siparisleriKur($token, ['lara' => self::LARA]);

        $yanit = $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => array_values($siparisler),
        ]);

        $yanit->assertStatus(409);
        $this->assertSame(0, $this->routeCredits($a['tenant']->id), 'sayaç eksiye düşmez');

        // Mağaza kuralı (BRIEF): mesajda satın alma/fiyat/yükseltme çağrısı OLAMAZ.
        $mesaj = mb_strtolower((string) $yanit->json('message'));
        foreach (['satın al', 'fiyat', 'abone', 'yükselt', 'paket', '₺'] as $yasak) {
            $this->assertStringNotContainsString($yasak, $mesaj);
        }
    }

    #[Test]
    public function siralanacak_gecerli_siparis_yoksa_kontor_yanmaz(): void
    {
        // Boş bir işlem için kontör harcamak kullanıcıya haksızlık olurdu.
        $a = $this->makeTenant('a');
        $this->setRouteCredits($a['tenant']->id, 7);
        $token = $this->tokenFor($a['patron']);

        $this->asToken($token)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [(string) Str::uuid7()], // hiç var olmayan sipariş
        ])->assertStatus(422);

        $this->assertSame(7, $this->routeCredits($a['tenant']->id));
    }

    #[Test]
    public function baska_bayinin_siparisi_siraya_hic_girmez(): void
    {
        // RLS kapısı: B'nin siparişi A'nın isteğine konsa bile sessizce düşer.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $this->setRouteCredits($a['tenant']->id, 5);

        $aToken = $this->tokenFor($a['patron']);
        $bToken = $this->tokenFor($b['patron']);

        $aSiparis = $this->siparisleriKur($aToken, ['lara' => self::LARA]);
        $bSiparis = $this->siparisleriKur($bToken, ['kepez' => self::KEPEZ]);

        $yanit = $this->asToken($aToken)->postJson('/api/v1/orders/auto-route', [
            'order_ids' => [$aSiparis['lara'], $bSiparis['kepez']],
        ]);

        $yanit->assertOk();
        $this->assertSame([$aSiparis['lara']], $yanit->json('order'));
    }

    #[Test]
    public function tokensiz_erisim_401_verir(): void
    {
        $this->postJson('/api/v1/orders/auto-route', ['order_ids' => [(string) Str::uuid7()]])
            ->assertUnauthorized();
    }

    // ── yardımcılar ─────────────────────────────────────────────────────────────────────────

    /**
     * Her ad için: müşteri + birincil adres (koordinatlı) + o müşteriye AÇIK bir sipariş.
     * Hepsi normal senkron yüzeyinden (push) yazılır — test kurgusu üretim yolunu kullanır.
     *
     * @param  array<string, array{0: float, 1: float}>  $noktalar
     * @return array<string, string> ad → sipariş kimliği
     */
    private function siparisleriKur(string $token, array $noktalar): array
    {
        $olaylar = [];
        $siparisIdler = [];

        foreach ($noktalar as $ad => [$lat, $lng]) {
            $musteriId = (string) Str::uuid7();
            $siparisId = (string) Str::uuid7();
            $siparisIdler[$ad] = $siparisId;

            $olaylar[] = $this->customerUpsert(['id' => $musteriId, 'name' => 'Müşteri '.$ad]);
            $olaylar[] = $this->event('customer_address', 'upsert', [
                'id' => (string) Str::uuid7(),
                'customer_id' => $musteriId,
                'address_text' => $ad.' Mah. 1. Sk.',
                'lat' => $lat,
                'lng' => $lng,
                'is_primary' => true,
            ]);
            $olaylar[] = $this->orderCreated(
                [$this->line(['product_name' => 'Damacana', 'unit_price_kurus' => 4500, 'qty' => 1])],
                ['id' => $siparisId, 'customer_id' => $musteriId],
            );
        }

        $this->pushEvents($token, $olaylar)->assertOk();

        return $siparisIdler;
    }

    private function setRouteCredits(string $tenantId, int $adet): void
    {
        Provisioning::asOwner(function () use ($tenantId, $adet) {
            Tenant::query()->whereKey($tenantId)->update(['route_credits' => $adet]);
        });
    }

    private function routeCredits(string $tenantId): int
    {
        return (int) Provisioning::asOwner(
            fn () => Tenant::query()->whereKey($tenantId)->value('route_credits')
        );
    }
}
