<?php

namespace Tests\Feature\Api;

use App\Models\CashHandover;
use App\Models\Customer;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\OrderEvent;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 4 — kurye (DECISIONS "Faz 4 — mimari"). Kapsam: olay-kaynaklı sipariş ATAMA (assigned_user_id
 * önbelleği olaylardan türer), TESLİM İDEMPOTENSİ (deterministik client_event_id → tek defter seti,
 * çift-dokunma imkânsız), KASA DEVRİ (append-only cash_handovers mutabakat kaydı), nakit ATFI
 * (collected_by_user_id). Gerçek Postgres 16 + RLS'e koşar (ApiTestCase).
 */
class CourierSyncTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function siparis_atama_assigned_user_id_onbellegini_olaydan_turetir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $order = $this->orderCreated([$this->line()]);
        $orderId = $order['payload']['order']['id'];
        $this->pushEvents($token, [$order])->assertJsonPath('results.0.status', 'applied');

        // Kuryeye ata → önbellek assigned olayından türer.
        $this->pushEvents($token, [$this->orderEvent('assigned', [
            'order_id' => $orderId, 'assigned_user_id' => $a['kurye']->id,
        ])])->assertJsonPath('results.0.status', 'applied');
        $assigned = $this->asOwner(fn () => Order::query()->find($orderId));
        $this->assertSame($a['kurye']->id, $assigned->assigned_user_id);

        // Geri al → null.
        $this->pushEvents($token, [$this->orderEvent('unassigned', ['order_id' => $orderId])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertNull($this->asOwner(fn () => Order::query()->find($orderId)->assigned_user_id));
    }

    #[Test]
    public function son_atama_kazanir_operatore_yeniden_atama_kuryeyi_ezer(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $order = $this->orderCreated([$this->line()]);
        $orderId = $order['payload']['order']['id'];
        $this->pushEvents($token, [$order]);

        $t1 = now()->subMinutes(2)->toIso8601String();
        $t2 = now()->toIso8601String();
        $this->pushEvents($token, [$this->orderEvent('assigned',
            ['order_id' => $orderId, 'assigned_user_id' => $a['kurye']->id], ['occurred_at' => $t1])]);
        $this->pushEvents($token, [$this->orderEvent('assigned',
            ['order_id' => $orderId, 'assigned_user_id' => $a['operator']->id], ['occurred_at' => $t2])]);

        $final = $this->asOwner(fn () => Order::query()->find($orderId));
        $this->assertSame($a['operator']->id, $final->assigned_user_id, 'En son atama (operator) kazanmalı.');
    }

    #[Test]
    public function teslim_idempotensi_ayni_deterministik_id_iki_kez_tek_defter_seti_birakir(): void
    {
        // İki cihaz aynı siparişi offline teslim eder → uuid5 ile AYNI client_event_id'ler üretir.
        // Sunucu processed_events UNIQUE bunları duplicate olarak tekilleştirir → TEK defter seti.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Teslim Müşteri']);
        $customerId = $cust['payload']['id'];
        $order = $this->orderCreated([$this->line(['unit_price_kurus' => 9000, 'qty' => 1])], ['customer_id' => $customerId]);
        $orderId = $order['payload']['order']['id'];
        $this->pushEvents($token, [$cust, $order])->assertOk();

        // Teslim partisi: delivered olay + ledger debit + ledger payment, hepsi DETERMİNİSTİK
        // client_event_id (aynı siparişten türer). Cihaz 1 gönderir.
        $deliverCeid = (string) Str::uuid7();
        $debitId = (string) Str::uuid7();
        $paymentId = (string) Str::uuid7();
        $batch = [
            $this->orderEvent('delivered', ['order_id' => $orderId, 'payment_type' => 'nakit'],
                ['client_event_id' => $deliverCeid]),
            $this->ledgerEntry(['id' => $debitId, 'customer_id' => $customerId, 'entry_type' => 'debit', 'amount_kurus' => 9000],
                ['client_event_id' => $debitId]),
            $this->ledgerEntry(['id' => $paymentId, 'customer_id' => $customerId, 'entry_type' => 'payment',
                'amount_kurus' => -9000, 'payment_type' => 'nakit', 'collected_by_user_id' => $a['kurye']->id],
                ['client_event_id' => $paymentId]),
        ];
        $first = $this->pushEvents($token, $batch);
        $first->assertJsonPath('results.0.status', 'applied');
        $first->assertJsonPath('results.1.status', 'applied');
        $first->assertJsonPath('results.2.status', 'applied');

        // Cihaz 2 AYNI deterministik id'lerle teslim eder → hepsi duplicate, çift defter YOK.
        $second = $this->pushEvents($token, $batch);
        $second->assertJsonPath('results.0.status', 'duplicate');
        $second->assertJsonPath('results.1.status', 'duplicate');
        $second->assertJsonPath('results.2.status', 'duplicate');

        $entryCount = $this->asOwner(fn () => LedgerEntry::query()->where('customer_id', $customerId)->count());
        $this->assertSame(2, $entryCount, 'Tek debit + tek payment kalmalı (çift teslim tekilleşti).');
        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(0, $balance, 'Peşin teslim net borç 0; çift teslim bakiyeyi bozmadı.');
        $delivered = $this->asOwner(fn () => OrderEvent::query()->where('order_id', $orderId)->where('event_type', 'delivered')->count());
        $this->assertSame(1, $delivered, 'Tek delivered order olayı kalmalı.');
    }

    #[Test]
    public function kasa_devri_kalici_append_only_kayit_ve_snapshot(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // Kurye 30000 nakit sayar, sistem 32000 bekliyordu → 2000 eksik (kanıt olarak durur).
        $handover = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'to_user_id' => $a['patron']->id,
            'counted_cash_kurus' => 30000,
            'expected_cash_kurus' => 32000,
            'diff_kurus' => -2000,
            'note' => 'gun sonu',
        ]);
        $this->pushEvents($token, [$handover])->assertJsonPath('results.0.status', 'applied');

        $row = $this->asOwner(fn () => CashHandover::query()->find($handover['payload']['id']));
        $this->assertNotNull($row);
        $this->assertSame(-2000, $row->diff_kurus, 'Eksik para kanıt olarak durmalı (BRIEF).');
        $this->assertSame($a['kurye']->id, $row->from_user_id);
        $this->assertSame($a['patron']->id, $row->to_user_id);

        // Snapshot kasa devrini taşır (append tablosu tam çekilir).
        $snap = $this->pullSince($token, 0);
        $this->assertCount(1, $snap->json('entities.cash_handover'));
        $this->assertSame(-2000, $snap->json('entities.cash_handover.0.diff_kurus'));
    }

    #[Test]
    public function ayni_kasa_devri_iki_kez_gonderilirse_tek_kayit(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $handover = $this->cashHandover([
            'from_user_id' => $a['kurye']->id, 'counted_cash_kurus' => 10000, 'expected_cash_kurus' => 10000,
        ]);
        $this->pushEvents($token, [$handover])->assertJsonPath('results.0.status', 'applied');
        // Retry (aynı client_event_id) → duplicate.
        $this->pushEvents($token, [$handover])->assertJsonPath('results.0.status', 'duplicate');

        $count = $this->asOwner(fn () => CashHandover::query()->count());
        $this->assertSame(1, $count);
    }

    #[Test]
    public function ledger_collected_by_user_id_yazilir_ve_snapshotta_gelir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Nakit Müşteri']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'payment', 'amount_kurus' => -5000,
            'payment_type' => 'nakit', 'collected_by_user_id' => $a['kurye']->id,
        ])])->assertJsonPath('results.0.status', 'applied');

        $collected = $this->asOwner(fn () => LedgerEntry::query()->where('customer_id', $customerId)->value('collected_by_user_id'));
        $this->assertSame($a['kurye']->id, $collected);
    }
}
