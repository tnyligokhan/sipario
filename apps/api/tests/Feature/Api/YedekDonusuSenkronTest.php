<?php

namespace Tests\Feature\Api;

use App\Models\LedgerEntry;
use App\Models\Order;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * 13.11.2026 yedek dönüşü senkron onarımı testleri.
 *
 *  1. İstemci imleci (`since`) sunucunun güncel sayacından (`current_seq`) büyük kaldığında
 *     sunucu son 7 günün deltalarını döner ve imleci `current_seq`e hizalar.
 *  2. Kurtarma sırasında iki cihaz aynı sipariş veya defter kimliğini (`id`) farklı
 *     `client_event_id` ile gönderdiğinde aynı kiracı içinde `duplicate` ile yakınsar;
 *     başka kiracının aynı kimliği kullanma denemesi ise `rejected` kalır.
 */
class YedekDonusuSenkronTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function istemci_imleci_sunucu_sayacindan_ilerideyse_son_degisiklikler_doner_ve_imlec_hizalanir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $musteri = $this->customerUpsert(['name' => 'Yedek Sonrası Müşteri']);
        $this->pushEvents($token, [$musteri])->assertJsonPath('current_seq', 1);

        // Telefonun lastPulledSeq değeri yedek öncesi 500'de kalmış, sunucu ise seq=1'de.
        $pull = $this->pullSince($token, 500);
        $pull->assertOk();
        $pull->assertJsonPath('mode', 'delta');
        $pull->assertJsonPath('cursor', 1);
        $pull->assertJsonPath('current_seq', 1);
        $this->assertCount(1, $pull->json('changes'));
        $this->assertSame($musteri['payload']['id'], $pull->json('changes.0.entity_id'));
    }

    #[Test]
    public function ayni_bayide_ayni_siparis_ve_defter_kimligi_farkli_olay_kimligiyle_gelirse_duplicate_doner(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $siparisId = (string) Str::uuid7();
        $ilkSiparis = $this->orderCreated([$this->line()], ['id' => $siparisId]);
        $ikinciSiparis = $this->orderCreated([$this->line()], ['id' => $siparisId]);

        $this->pushEvents($tokenA, [$ilkSiparis])->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($tokenA, [$ikinciSiparis])->assertJsonPath('results.0.status', 'duplicate');

        // Başka bayi aynı sipariş id'sini kullanırsa RLS altında görünmez → global PK 23505 → rejected.
        $this->pushEvents($tokenB, [$this->orderCreated([$this->line()], ['id' => $siparisId])])
            ->assertJsonPath('results.0.status', 'rejected');

        $defterId = (string) Str::uuid7();
        $ilkDefter = $this->ledgerEntry(['id' => $defterId, 'entry_type' => 'debit', 'amount_kurus' => 5000]);
        $ikinciDefter = $this->ledgerEntry(['id' => $defterId, 'entry_type' => 'debit', 'amount_kurus' => 5000]);

        $this->pushEvents($tokenA, [$ilkDefter])->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($tokenA, [$ikinciDefter])->assertJsonPath('results.0.status', 'duplicate');

        $this->pushEvents($tokenB, [$this->ledgerEntry(['id' => $defterId, 'entry_type' => 'debit', 'amount_kurus' => 5000])])
            ->assertJsonPath('results.0.status', 'rejected');

        $this->assertSame(1, $this->asOwner(fn () => Order::query()->whereKey($siparisId)->count()));
        $this->assertSame(1, $this->asOwner(fn () => LedgerEntry::query()->whereKey($defterId)->count()));
    }
}
