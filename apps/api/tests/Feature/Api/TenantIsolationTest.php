<?php

namespace Tests\Feature\Api;

use App\Models\CouponBalance;
use App\Models\CouponMovement;
use App\Models\Customer;
use App\Models\Device;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\OrderLine;
use App\Models\Product;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * KIRMIZI ÇİZGİ #1 — bir bayi başka bayinin verisini ASLA göremez/değiştiremez.
 *
 * Matris: her tenant-scope endpoint için "B'nin kaydını A'nın token'ıyla iste" senaryosu.
 *  - Okuma (show):   B'nin id'si A token'ıyla → 404 (RLS satırı gizler, model binding düşer).
 *  - Liste (index):  A yalnız kendi kayıtlarını görür; B'nin hiçbir kaydı sızmaz.
 *  - Yazma (store):  A, B'nin device_id'sini gönderirse B'nin satırı ne görünür ne değişir → 409.
 *
 * Not (Faz 1 kapsamı): devices kaynağında ayrı PUT/DELETE route'u YOKTUR; yazma yolu idempotent
 * POST /devices'tır (updateOrCreate). Cross-tenant yazma izolasyonu bu yüzden store→409 + "B'nin
 * satırı değişmedi" doğrulamasıyla kanıtlanır. Yeni tenant-scope endpoint eklendiğinde bu matrise
 * satır eklenmelidir; RouteCoverageGuardTest testsiz eklemeyi build'de kırar.
 */
class TenantIsolationTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function devices_show_baska_bayinin_kaydini_404_verir(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);

        // B'nin cihazının GERÇEK, geçerli id'si — ama A'nın bağlamında RLS onu gizler.
        $response = $this->asToken($tokenA)->getJson("/api/v1/devices/{$b['device']->id}");

        $response->assertNotFound();
    }

    #[Test]
    public function devices_index_yalnizca_kendi_bayinin_cihazlarini_dondurur(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);

        $response = $this->asToken($tokenA)->getJson('/api/v1/devices');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->all();

        // A yalnız kendi cihazını görür; B'nin cihaz id'si listede ASLA yer almaz.
        $this->assertContains($a['device']->id, $ids);
        $this->assertNotContains($b['device']->id, $ids);
        $this->assertCount(1, $ids, 'A yalnız kendi tek cihazını görmeli.');
    }

    #[Test]
    public function devices_store_baska_bayinin_device_idsini_409_verir_ve_o_satiri_degistirmez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);

        $bDeviceId = $b['device']->id;
        $bOriginalTenant = $b['device']->tenant_id;

        // A, B'ye ait mevcut device_id ile kayıt denemesi yapar.
        $response = $this->asToken($tokenA)->postJson('/api/v1/devices', [
            'device_id' => $bDeviceId,
            'platform' => 'android',
            'model' => 'A-nin-ele-gecirme-denemesi',
        ]);

        $response->assertStatus(409);

        // B'nin cihaz satırı ne A'ya geçti ne de modeli değişti (owner ile doğrula).
        $fresh = $this->asOwner(fn () => Device::query()->find($bDeviceId));
        $this->assertNotNull($fresh);
        $this->assertSame($bOriginalTenant, $fresh->tenant_id, 'B cihazının tenant_id\'si değişmemeli.');
        $this->assertNotSame('A-nin-ele-gecirme-denemesi', $fresh->model, 'B cihazının modeli ezilmemeli.');
    }

    #[Test]
    public function auth_me_yalnizca_kendi_tenant_baglamini_dondurur(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);

        $response = $this->asToken($tokenA)->getJson('/api/v1/auth/me');

        $response->assertOk();
        $response->assertJsonPath('tenant.id', $a['tenant']->id);
        $response->assertJsonPath('user.id', $a['patron']->id);
        // B'nin tenant/kullanıcı kimliği yanıtta hiçbir yerde geçmez.
        $this->assertStringNotContainsString($b['tenant']->id, $response->getContent());
        $this->assertStringNotContainsString($b['patron']->id, $response->getContent());
    }

    #[Test]
    public function bir_bayinin_tokeni_diger_bayinin_var_olmayan_cihaz_idsiyle_de_404_verir(): void
    {
        // Rastgele (hiç var olmayan) bir uuid de 404 vermeli — enumeration/kaçak yok.
        $a = $this->makeTenant('a');
        $tokenA = $this->tokenFor($a['patron']);

        $response = $this->asToken($tokenA)->getJson('/api/v1/devices/'.Str::uuid7());

        $response->assertNotFound();
    }

    #[Test]
    public function token_olmadan_korumali_endpointler_401_verir(): void
    {
        // Bağlam kurulamaz → RLS sıfır satır → auth:sanctum 401. (Güvenli varsayılanın uçtan ucu.)
        $this->getJson('/api/v1/devices')->assertUnauthorized();
        $this->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->postJson('/api/v1/devices', [
            'device_id' => (string) Str::uuid7(),
            'platform' => 'android',
        ])->assertUnauthorized();
        $this->getJson('/api/v1/sync/pull')->assertUnauthorized();
        $this->postJson('/api/v1/sync/push', ['events' => []])->assertUnauthorized();
    }

    #[Test]
    public function sync_pull_baska_bayinin_verisini_asla_dondurmez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        // Her bayi kendi müşterisini push eder.
        $custA = $this->customerUpsert(['name' => 'A Müşterisi']);
        $custB = $this->customerUpsert(['name' => 'B Müşterisi']);
        $this->pushEvents($tokenA, [$custA])->assertOk();
        $this->pushEvents($tokenB, [$custB])->assertOk();

        // B'nin snapshot'ı yalnız kendi müşterisini içerir; A'nınki sızmaz.
        $snapB = $this->pullSince($tokenB, 0);
        $snapB->assertOk();
        $namesB = collect($snapB->json('entities.customer'))->pluck('id')->all();
        $this->assertContains($custB['payload']['id'], $namesB);
        $this->assertNotContains($custA['payload']['id'], $namesB);

        // A'nın seq akışı (delta) da B'nin değişikliklerini içermez: A'nın current_seq'i yalnız kendi
        // tek olayını sayar (B'nin push'u A'nın sayacını ilerletmez — tenant başına monoton).
        $this->assertSame(1, $snapB->json('current_seq'));
        $snapA = $this->pullSince($tokenA, 0);
        $this->assertSame(1, $snapA->json('current_seq'));
    }

    #[Test]
    public function sync_push_baska_bayinin_customer_idsine_siparis_baglayamaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        // A bir müşteri oluşturur.
        $custA = $this->customerUpsert(['name' => 'A Müşterisi']);
        $this->pushEvents($tokenA, [$custA])->assertOk();
        $aCustomerId = $custA['payload']['id'];

        // B, A'nın customer_id'sine sipariş bağlamayı dener → RLS önden reddeder (FK zehirlenmez).
        $order = $this->orderCreated([$this->line()], ['customer_id' => $aCustomerId]);
        $response = $this->pushEvents($tokenB, [$order]);
        $response->assertOk();
        $this->assertSame('rejected', $response->json('results.0.status'));

        // B'de hiç sipariş oluşmadı; A'nın müşterisi B için görünmez kaldı.
        $snapB = $this->pullSince($tokenB, 0);
        $this->assertCount(0, $snapB->json('entities.order'));
        $this->assertCount(0, $snapB->json('entities.customer'));
    }

    #[Test]
    public function sync_push_baska_bayinin_order_idsine_satir_ekleyemez_veya_teslim_edemez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $orderA = $this->orderCreated([$this->line()]);
        $this->pushEvents($tokenA, [$orderA])->assertOk();
        $orderAId = $orderA['payload']['order']['id'];

        // B, A'nın order_id'sine satır eklemeyi dener — RLS altında Order::find() A'nın satırını
        // hiç göremez (bulunamadı → reddedilir), B'nin bağlamında sipariş "yok" sayılır.
        $lineAdd = $this->event('order', 'line_added', ['order_id' => $orderAId, 'line' => $this->line()]);
        $this->pushEvents($tokenB, [$lineAdd])
            ->assertJsonPath('results.0.status', 'rejected');

        // B, A'nın siparişini teslim etmeyi dener.
        $deliver = $this->event('order', 'delivered', ['order_id' => $orderAId, 'payment_type' => 'nakit']);
        $this->pushEvents($tokenB, [$deliver])
            ->assertJsonPath('results.0.status', 'rejected');

        // A'nın siparişi hiç değişmedi: hâlâ tek satır, hâlâ 'open'.
        $lineCount = $this->asOwner(fn () => OrderLine::query()->where('order_id', $orderAId)->count());
        $this->assertSame(1, $lineCount);
        $status = $this->asOwner(fn () => Order::query()->find($orderAId)?->status);
        $this->assertSame('open', $status);
    }

    #[Test]
    public function sync_push_ledger_baska_bayinin_customer_idsine_kayit_ekleyemez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $custA = $this->customerUpsert(['name' => 'A Müşterisi']);
        $this->pushEvents($tokenA, [$custA])->assertOk();
        $aCustomerId = $custA['payload']['id'];

        // B, A'nın customer_id'sine defter kaydı düşmeyi dener → reddedilir, A'nın bakiyesi etkilenmez.
        $ledger = $this->ledgerEntry(['customer_id' => $aCustomerId, 'amount_kurus' => 50000]);
        $this->pushEvents($tokenB, [$ledger])
            ->assertJsonPath('results.0.status', 'rejected');

        $balance = $this->asOwner(fn () => Customer::query()->find($aCustomerId)?->balance_kurus);
        $this->assertSame(0, $balance, 'B\'nin denemesi A\'nın bakiyesini etkilememeli.');
        $entryCount = $this->asOwner(fn () => LedgerEntry::query()->where('customer_id', $aCustomerId)->count());
        $this->assertSame(0, $entryCount);
    }

    #[Test]
    public function sync_delta_ic_ice_pushlarda_diger_bayinin_degisikligini_asla_gostermez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        // A ve B sırayla, iç içe (interleaved) birden fazla olay push eder.
        $this->pushEvents($tokenA, [$this->customerUpsert(['name' => 'A1'])])->assertJsonPath('current_seq', 1);
        $this->pushEvents($tokenB, [$this->customerUpsert(['name' => 'B1'])])->assertJsonPath('current_seq', 1);
        $this->pushEvents($tokenA, [$this->customerUpsert(['name' => 'A2'])])->assertJsonPath('current_seq', 2);
        $this->pushEvents($tokenB, [$this->customerUpsert(['name' => 'B2'])])->assertJsonPath('current_seq', 2);

        // A'nın since=0 delta'sı yalnız kendi iki değişikliğini içerir; B'ninkiler hiç görünmez.
        $deltaA = $this->pullSince($tokenA, 0);
        $namesA = collect($deltaA->json('entities.customer'))->pluck('name')->all();
        sort($namesA);
        $this->assertSame(['A1', 'A2'], $namesA);

        $deltaB = $this->pullSince($tokenB, 1);
        $namesB = collect($deltaB->json('changes'))->pluck('payload.name')->all();
        $this->assertSame(['B2'], $namesB, 'B\'nin delta akışına A\'nın olayları asla karışmamalı.');
    }

    #[Test]
    public function sync_push_siparis_satirinda_baska_bayinin_product_idsine_referans_veremez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $prodA = $this->event('product', 'upsert', [
            'id' => (string) Str::uuid7(), 'name' => 'A Ürünü', 'unit_price_kurus' => 1000,
        ]);
        $this->pushEvents($tokenA, [$prodA])->assertOk();
        $aProductId = $prodA['payload']['id'];

        // B, siparişinde A'nın product_id'sine referans vermeyi dener → reddedilir.
        $order = $this->orderCreated([$this->line(['product_id' => $aProductId])]);
        $response = $this->pushEvents($tokenB, [$order]);
        $response->assertJsonPath('results.0.status', 'rejected');

        // B'de hiç sipariş oluşmadı; A'nın ürünü A'da hâlâ tek başına duruyor.
        $snapB = $this->pullSince($tokenB, 0);
        $this->assertCount(0, $snapB->json('entities.order'));
        $productCount = $this->asOwner(fn () => Product::query()->count());
        $this->assertSame(1, $productCount, 'A\'nın ürünü B\'nin denemesinden etkilenmemeli.');
    }

    #[Test]
    public function sync_push_ledger_related_order_idsinde_baska_bayinin_siparisine_referans_veremez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $orderA = $this->orderCreated([$this->line()]);
        $this->pushEvents($tokenA, [$orderA])->assertOk();
        $aOrderId = $orderA['payload']['order']['id'];

        // B, defter kaydında A'nın order_id'sini related_order_id olarak vermeyi dener → reddedilir.
        $ledger = $this->ledgerEntry(['related_order_id' => $aOrderId, 'customer_id' => null]);
        $response = $this->pushEvents($tokenB, [$ledger]);
        $response->assertJsonPath('results.0.status', 'rejected');

        $entryCount = $this->asOwner(fn () => LedgerEntry::query()->count());
        $this->assertSame(0, $entryCount, 'B için hiçbir defter kaydı oluşmamalı.');
    }

    #[Test]
    public function sync_push_kupon_baska_bayinin_customer_idsine_hareket_ekleyemez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $custA = $this->customerUpsert(['name' => 'A Müşterisi']);
        $this->pushEvents($tokenA, [$custA])->assertOk();
        $aCustomerId = $custA['payload']['id'];

        // B, A'nın customer_id'sine kupon hareketi düşmeyi dener → RLS önden reddeder (FK zehirlenmez).
        $coupon = $this->couponMovement('grant', ['customer_id' => $aCustomerId, 'qty_delta' => 5]);
        $this->pushEvents($tokenB, [$coupon])
            ->assertJsonPath('results.0.status', 'rejected');

        // Ne hareket ne bakiye oluştu; A'nın kupon durumu B için görünmez kaldı.
        $moveCount = $this->asOwner(fn () => CouponMovement::query()->count());
        $this->assertSame(0, $moveCount, 'B için hiçbir kupon hareketi oluşmamalı.');
        $balCount = $this->asOwner(fn () => CouponBalance::query()->count());
        $this->assertSame(0, $balCount, 'B için hiçbir kupon bakiyesi oluşmamalı.');
    }

    #[Test]
    public function sync_push_ledger_reverses_entry_idsinde_baska_bayinin_kaydina_referans_veremez(): void
    {
        // Ters kayıt yalnız AYNI bayinin bir defter satırını düzeltebilir (bileşik self-FK + app kontrolü).
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $custA = $this->customerUpsert(['name' => 'A Müşterisi']);
        $this->pushEvents($tokenA, [$custA])->assertOk();
        $entryA = $this->ledgerEntry(['customer_id' => $custA['payload']['id'], 'entry_type' => 'debit', 'amount_kurus' => 5000]);
        $this->pushEvents($tokenA, [$entryA])->assertJsonPath('results.0.status', 'applied');
        $aEntryId = $entryA['payload']['id'];

        // B, kendi correction'ında A'nın entry'sini reverses_entry_id olarak vermeyi dener → reddedilir.
        $custB = $this->customerUpsert(['name' => 'B Müşterisi']);
        $this->pushEvents($tokenB, [$custB])->assertOk();
        $this->pushEvents($tokenB, [$this->ledgerEntry([
            'customer_id' => $custB['payload']['id'], 'entry_type' => 'correction',
            'amount_kurus' => -5000, 'reverses_entry_id' => $aEntryId,
        ])])->assertJsonPath('results.0.status', 'rejected');

        $bCount = $this->asOwner(fn () => LedgerEntry::query()->where('customer_id', $custB['payload']['id'])->count());
        $this->assertSame(0, $bCount, 'B için hiçbir düzeltme kaydı oluşmamalı.');
    }

    #[Test]
    public function sync_push_kupon_baska_bayinin_urun_siparis_ve_hareketine_referans_veremez(): void
    {
        // Kupon hareketinin TÜM yabancı referansları (product_id, related_order_id, reverses_movement_id)
        // yazımdan önce RLS kapsamında doğrulanır — başka bayininkine bağlanamaz (kırmızı çizgi #1).
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $prodA = $this->event('product', 'upsert', [
            'id' => (string) Str::uuid7(), 'name' => 'A Ürün', 'unit_price_kurus' => 1000,
        ]);
        $custA = $this->customerUpsert(['name' => 'A Müşterisi']);
        $this->pushEvents($tokenA, [$prodA, $custA])->assertOk();
        $orderA = $this->orderCreated([$this->line()], ['customer_id' => $custA['payload']['id']]);
        $this->pushEvents($tokenA, [$orderA])->assertOk();
        $moveA = $this->couponMovement('grant', ['customer_id' => $custA['payload']['id'], 'qty_delta' => 3]);
        $this->pushEvents($tokenA, [$moveA])->assertJsonPath('results.0.status', 'applied');

        $custB = $this->customerUpsert(['name' => 'B Müşterisi']);
        $this->pushEvents($tokenB, [$custB])->assertOk();
        $cidB = $custB['payload']['id'];

        // Her yabancı referans ayrı ayrı reddedilmeli.
        $this->pushEvents($tokenB, [$this->couponMovement('grant', [
            'customer_id' => $cidB, 'qty_delta' => 1, 'product_id' => $prodA['payload']['id'],
        ])])->assertJsonPath('results.0.status', 'rejected');
        $this->pushEvents($tokenB, [$this->couponMovement('grant', [
            'customer_id' => $cidB, 'qty_delta' => 1, 'related_order_id' => $orderA['payload']['order']['id'],
        ])])->assertJsonPath('results.0.status', 'rejected');
        $this->pushEvents($tokenB, [$this->couponMovement('correction', [
            'customer_id' => $cidB, 'qty_delta' => 1, 'reverses_movement_id' => $moveA['payload']['id'],
        ])])->assertJsonPath('results.0.status', 'rejected');

        $bMoveCount = $this->asOwner(fn () => CouponMovement::query()->where('customer_id', $cidB)->count());
        $this->assertSame(0, $bMoveCount, 'B için hiçbir kupon hareketi oluşmamalı (tüm cross-tenant referanslar reddedildi).');
    }

    #[Test]
    public function sync_pull_kupon_hareket_ve_bakiyesinde_baska_bayinin_verisini_gostermez(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $custA = $this->customerUpsert(['name' => 'A']);
        $this->pushEvents($tokenA, [$custA])->assertOk();
        $this->pushEvents($tokenA, [$this->couponMovement('grant', ['customer_id' => $custA['payload']['id'], 'qty_delta' => 4])]);

        $custB = $this->customerUpsert(['name' => 'B']);
        $this->pushEvents($tokenB, [$custB])->assertOk();
        $this->pushEvents($tokenB, [$this->couponMovement('grant', ['customer_id' => $custB['payload']['id'], 'qty_delta' => 7])]);

        // B'nin snapshot'ı yalnız kendi kupon verisini içerir.
        $snapB = $this->pullSince($tokenB, 0);
        $this->assertCount(1, $snapB->json('entities.coupon_movement'));
        $this->assertCount(1, $snapB->json('entities.coupon_balance'));
        $this->assertSame(7, $snapB->json('entities.coupon_balance.0.balance_qty'), 'B yalnız kendi 7 kupon bakiyesini görür.');
        // A'nın müşteri id'si B'nin yanıtında hiçbir yerde geçmez.
        $this->assertStringNotContainsString($custA['payload']['id'], $snapB->getContent());
    }
}
