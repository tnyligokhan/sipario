<?php

namespace Tests\Feature\Api\Concerns;

use App\Models\Tenant;
use App\Support\Provisioning;
use Illuminate\Support\Str;

/**
 * "Oto Sırala (rota)" testlerinin ortak kurgusu: koordinatlı duraklar + kontör okuma/yazma.
 * `AutoRouteTest` (sıra ve kontör kuralları) ile `RotaMotoruTest` (motor seçimi ve düşme)
 * aynı kurguyu kullanır; kopyalanmış bir kurulum iki dosyada ayrı ayrı bayatlardı.
 */
trait BuildsRouteStops
{
    /**
     * Her ad için: müşteri + birincil adres (koordinatlı) + o müşteriye AÇIK bir sipariş.
     * Hepsi normal senkron yüzeyinden (push) yazılır — test kurgusu üretim yolunu kullanır.
     *
     * @param  array<string, array{0: float, 1: float}>  $noktalar
     * @return array<string, string> ad → sipariş kimliği
     */
    protected function siparisleriKur(string $token, array $noktalar): array
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

    protected function setRouteCredits(string $tenantId, int $adet): void
    {
        Provisioning::asOwner(function () use ($tenantId, $adet) {
            Tenant::query()->whereKey($tenantId)->update(['route_credits' => $adet]);
        });
    }

    protected function routeCredits(string $tenantId): int
    {
        return (int) Provisioning::asOwner(
            fn () => Tenant::query()->whereKey($tenantId)->value('route_credits')
        );
    }
}
