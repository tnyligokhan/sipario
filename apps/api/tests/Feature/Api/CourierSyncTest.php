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
 * önbelleği olaylardan türer), ATAMANIN KURYEYE ULAŞMASI (atama pull'da kuryenin KENDİ tokenıyla
 * iniyor mu), TESLİM İDEMPOTENSİ (deterministik client_event_id → tek defter seti, çift-dokunma
 * imkânsız), KASA DEVRİ (append-only cash_handovers mutabakat kaydı), nakit ATFI
 * (collected_by_user_id). Gerçek Postgres 16 + RLS'e koşar (ApiTestCase).
 *
 * Atama testleri İKİ YARIYA ayrılır ve ikisi de gereklidir: önce atamanın SUNUCUDA doğru türetildiği
 * (assigned_user_id önbelleği), sonra o atamanın KURYENİN CİHAZINA ULAŞTIĞI. İkincisi olmadan
 * birincisi bir şey kanıtlamaz — "sunucuda doğru duran ama inmeyen alan YOKTUR" (migration 802'nin
 * dersi, DECISIONS 2026-07-29).
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

    /**
     * REGRESYON (reviewer bulgu #1): eşit occurred_at'te kazananı YALNIZ id tiebreak belirler — flaky'yi
     * doğuran tam senaryo. Diğer atama testleri farklı occurred_at kullanıyordu; bu, id-DESC tiebreak'ini
     * her koşuda DOĞRUDAN tetikler. assigned ve unassigned AYNI occurred_at; unassigned sonra insert
     * edildiğinden uuid7 order_event id'si daha büyük → deterministik kazanır → assigned_user_id null.
     * Fix (occurred_at, id) geri alınırsa (created_at'e dönülürse) bu test flaky/kırmızı olur.
     */
    #[Test]
    public function atama_esit_occurred_at_id_tiebreak_ile_deterministik(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $order = $this->orderCreated([$this->line()]);
        $orderId = $order['payload']['order']['id'];
        $this->pushEvents($token, [$order]);

        $t = now()->toIso8601String(); // İKİ olay da AYNI occurred_at → tiebreak = id.
        $this->pushEvents($token, [$this->orderEvent('assigned',
            ['order_id' => $orderId, 'assigned_user_id' => $a['kurye']->id], ['occurred_at' => $t])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($token, [$this->orderEvent('unassigned', ['order_id' => $orderId], ['occurred_at' => $t])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->assertNull(
            $this->asOwner(fn () => Order::query()->find($orderId)->assigned_user_id),
            'Eşit occurred_at: sonradan gelen unassigned (daha büyük uuid7 id) deterministik kazanmalı.'
        );
    }

    /**
     * SAHA ARIZASI: "patron siparişi kuryeye atadı, kuryenin telefonunda çıkmadı." Yukarıdaki atama
     * testleri arızanın YALNIZ SUNUCU yarısını eler (önbellek doğru türüyor mu); bu test İKİNCİ
     * yarıyı kalıcı olarak kapatır — atama kuryenin KENDİ tokenıyla, KENDİ imlecinden çektiği
     * DELTA'da gerçekten iniyor mu. Bir gün pull'a rol/atama kapsamı süzgeci sızarsa (sunucu
     * "kurye zaten göremez" diye satırı atlarsa) burası kırmızı yanar: sipariş satırı, `assigned`
     * olayı ve sipariş kalemi ÜÇÜ BİRDEN inmelidir — kurye ekranını bu üçünden çizer.
     *
     * ⚠️ KURULUM TUZAĞI (özgün yazarın ilk koşumu bu yüzden KIRMIZIYDI, kusur üründe değildi):
     * BOŞ bayide imleç 0 döner ve `since=0` tanım gereği SNAPSHOT demektir (SyncService::pull),
     * delta değil. Kuryenin "ilk senkronu"nu boş bayide kurarsan ikinci çağrı da snapshot olur ve
     * test delta yolunu HİÇ ölçmez. Gerçek cihazda imleç daima >0'dır (bayide zaten veri vardır);
     * o yüzden aşağıda önce bir müşteri push edilir — imleç ilerlesin, kuryenin ilk senkronu
     * sahadaki gibi >0 imleçle bitsin.
     */
    #[Test]
    public function kuryenin_hic_gormedigi_siparis_atandiginda_delta_pullda_cikar(): void
    {
        $a = $this->makeTenant('a');
        $patron = $this->tokenFor($a['patron']);
        $kurye = $this->tokenFor($a['kurye']);

        // Bayide zaten veri var (bkz. tuzak notu) → kuryenin ilk senkronu imleci >0 bırakır.
        $this->pushEvents($patron, [$this->customerUpsert(['name' => 'Eski Müşteri'])])
            ->assertJsonPath('results.0.status', 'applied');

        $ilk = $this->pullSince($kurye, 0)->assertOk();
        $imlec = (int) $ilk->json('cursor');
        $this->assertGreaterThan(0, $imlec, 'İmleç 0 kalırsa sonraki çağrı delta değil snapshot olur (tuzak notu).');
        $this->assertSame([], $ilk->json('entities.order'), 'Başlangıç: kurye bu siparişi HENÜZ görmedi.');

        // Patron siparişi açar ve kuryeye atar — kuryenin cihazı bu sırada senkron olmuyor.
        $order = $this->orderCreated([$this->line()]);
        $orderId = $order['payload']['order']['id'];
        $this->pushEvents($patron, [$order])->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($patron, [$this->orderEvent('assigned', [
            'order_id' => $orderId, 'assigned_user_id' => $a['kurye']->id,
        ])])->assertJsonPath('results.0.status', 'applied');

        // Kurye KENDİ tokenıyla KENDİ imlecinden çeker (sahadaki tur birebir bu).
        $delta = $this->pullSince($kurye, $imlec)->assertOk();
        $delta->assertJsonPath('mode', 'delta');
        $changes = collect($delta->json('changes'));

        $siparisSatirlari = $changes->where('entity_type', 'order')->where('entity_id', $orderId)->values();
        $this->assertNotEmpty($siparisSatirlari, 'Sipariş hiç inmediyse kurye onu göremez — arızanın ta kendisi.');
        $this->assertSame(
            $a['kurye']->id,
            $siparisSatirlari->last()['payload']['assigned_user_id'],
            'Kuryeye inen SON sipariş satırı atamayı taşımalı (assigned_user_id önbelleği).'
        );

        // İstemci atamayı olaylardan da türetir; `assigned` olayı inmezse iki taraf ıraksar.
        $atamaOlaylari = $changes->where('entity_type', 'order_event')
            ->filter(fn (array $c) => ($c['payload']['event_type'] ?? null) === 'assigned')->values();
        $this->assertCount(1, $atamaOlaylari, 'assigned order_event de inmeli.');
        $this->assertSame($a['kurye']->id, $atamaOlaylari->first()['payload']['payload']['assigned_user_id']);

        // Kalem inmezse kurye "ne götüreceğini" bilemez — sipariş boş görünür.
        $kalemler = $changes->where('entity_type', 'order_line')->values();
        $this->assertCount(1, $kalemler, 'Siparişin kalemi de aynı deltada inmeli.');
        $this->assertSame($orderId, $kalemler->first()['payload']['order_id']);
    }

    /**
     * SAHA ARIZASININ İKİNCİ YÜZÜ: sipariş önce operatördeydi, patron kuryeye DEVRETTİ. Devir bir
     * "yeni sipariş" değil, kuryenin ZATEN indirdiği bir satırın güncellenmesidir — ve tam bu yüzden
     * daha kolay kaçar: delta yalnız yeni varlıkları taşısaydı kurye siparişi hiç görmeden gün
     * biterdi. Kurye imlecini devirden ÖNCE alır (yani sipariş listesinde başkasının işi olarak
     * durur), sonraki turda devir deltası inmelidir.
     */
    #[Test]
    public function yeniden_atama_deltasi_yeni_kuryeye_ulasir(): void
    {
        $a = $this->makeTenant('a');
        $patron = $this->tokenFor($a['patron']);
        $kurye = $this->tokenFor($a['kurye']);

        $order = $this->orderCreated([$this->line()]);
        $orderId = $order['payload']['order']['id'];
        $this->pushEvents($patron, [$order])->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($patron, [$this->orderEvent('assigned',
            ['order_id' => $orderId, 'assigned_user_id' => $a['operator']->id],
            ['occurred_at' => now()->subMinutes(5)->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        // Kurye senkron olur: sipariş var ama OPERATÖRDE. İmleç burada >0 (tuzak notu artık geçerli değil,
        // bayide veri var) → sonraki çağrı gerçekten delta yolunu ölçer.
        $ilk = $this->pullSince($kurye, 0)->assertOk();
        $imlec = (int) $ilk->json('cursor');
        $this->assertSame(
            $a['operator']->id,
            collect($ilk->json('entities.order'))->firstWhere('id', $orderId)['assigned_user_id'],
            'Devirden önce sipariş operatörde görünmeli.'
        );

        // Patron devreder.
        $this->pushEvents($patron, [$this->orderEvent('assigned',
            ['order_id' => $orderId, 'assigned_user_id' => $a['kurye']->id])])
            ->assertJsonPath('results.0.status', 'applied');

        $changes = collect($this->pullSince($kurye, $imlec)->assertOk()->assertJsonPath('mode', 'delta')->json('changes'));
        $siparisSatirlari = $changes->where('entity_type', 'order')->where('entity_id', $orderId)->values();
        $this->assertNotEmpty($siparisSatirlari, 'Devir deltası hiç inmediyse kurye işi devraldığını öğrenemez.');
        $this->assertSame(
            $a['kurye']->id,
            $siparisSatirlari->last()['payload']['assigned_user_id'],
            'Devir sonrası satır kuryeyi göstermeli (son atama kazanır + delta ulaşır).'
        );
    }

    /**
     * ÜÇÜNCÜ YOL: kurye telefonu sıfırlanır / uygulamayı yeniden kurar → imleci 0'dır, yani DELTA
     * değil SNAPSHOT çeker. Snapshot ayrı bir kod yoludur (SyncService::snapshot, canlı satırları
     * doğrudan okur) ve orada bir rol/atama süzgeci olsaydı delta testleri bunu HİÇ görmezdi:
     * kurye bilerek atamadan SONRA kurulum yapar ve siparişi ilk senkronunda tam görmelidir.
     */
    #[Test]
    public function kurye_snapshotu_atamadan_sonra_alirsa_da_dogru_gorur(): void
    {
        $a = $this->makeTenant('a');
        $patron = $this->tokenFor($a['patron']);

        $order = $this->orderCreated([$this->line()]);
        $orderId = $order['payload']['order']['id'];
        $this->pushEvents($patron, [$order])->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($patron, [$this->orderEvent('assigned', [
            'order_id' => $orderId, 'assigned_user_id' => $a['kurye']->id,
        ])])->assertJsonPath('results.0.status', 'applied');

        // Kurye ATAMADAN SONRA ilk kez senkron olur (since=0 → snapshot).
        $snap = $this->pullSince($this->tokenFor($a['kurye']), 0)->assertOk();
        $snap->assertJsonPath('mode', 'snapshot');

        $siparis = collect($snap->json('entities.order'))->firstWhere('id', $orderId);
        $this->assertNotNull($siparis, 'Snapshot siparişi taşımalı — süzülürse yeni kurulan telefon boş açılır.');
        $this->assertSame($a['kurye']->id, $siparis['assigned_user_id']);

        $kalemler = collect($snap->json('entities.order_line'))->where('order_id', $orderId);
        $this->assertCount(1, $kalemler, 'Sipariş kalemi de snapshot ile inmeli.');

        $atamaOlaylari = collect($snap->json('entities.order_event'))
            ->where('order_id', $orderId)->where('event_type', 'assigned');
        $this->assertCount(1, $atamaOlaylari, 'assigned olayı snapshot ile de inmeli (istemci önbelleği olaylardan türetir).');
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
