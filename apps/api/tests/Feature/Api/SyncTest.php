<?php

namespace Tests\Feature\Api;

use App\Models\CouponBalance;
use App\Models\CouponMovement;
use App\Models\Customer;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\OrderEvent;
use App\Models\OrderLine;
use App\Models\Product;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * Senkron çekirdeğinin davranış sözleşmesi (DECISIONS senkron; korku #2 defter tutarlılığı).
 * Gerçek Postgres 16 + RLS'e koşar (ApiTestCase). Kapsam: idempotency, monoton seq, LWW çakışma
 * çözümü, snapshot/delta, tombstone, sipariş olay akışı, defter bakiye önbelleği.
 */
class SyncTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function push_musteri_olusturur_ve_snapshot_geri_dondurur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $event = $this->customerUpsert(['name' => 'Ahmet Yılmaz']);
        $response = $this->pushEvents($token, [$event]);

        $response->assertOk();
        $response->assertJsonPath('results.0.status', 'applied');
        $response->assertJsonPath('results.0.server_seq', 1);
        $response->assertJsonPath('current_seq', 1);
        // server_time middleware'den gelir (istemci offset'i).
        $this->assertNotNull($response->json('server_time'));

        $snap = $this->pullSince($token, 0);
        $snap->assertOk();
        $snap->assertJsonPath('mode', 'snapshot');
        $snap->assertJsonPath('cursor', 1);
        $customers = collect($snap->json('entities.customer'));
        $this->assertCount(1, $customers);
        $this->assertSame('Ahmet Yılmaz', $customers->first()['name']);
    }

    #[Test]
    public function ayni_client_event_id_iki_kez_push_edilirse_tek_kez_uygulanir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $event = $this->customerUpsert(['name' => 'Tekil Kayıt']);

        $first = $this->pushEvents($token, [$event]);
        $first->assertJsonPath('results.0.status', 'applied');
        $first->assertJsonPath('results.0.server_seq', 1);

        // Aynı olay tekrar (retry) → duplicate, aynı server_seq, seq ilerlemez.
        $second = $this->pushEvents($token, [$event]);
        $second->assertJsonPath('results.0.status', 'duplicate');
        $second->assertJsonPath('results.0.server_seq', 1);
        $second->assertJsonPath('current_seq', 1);

        $count = $this->asOwner(fn () => Customer::query()->count());
        $this->assertSame(1, $count);
    }

    #[Test]
    public function seq_monoton_artar_ve_delta_sirali_gelir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $c1 = $this->customerUpsert(['name' => 'Bir']);
        $c2 = $this->customerUpsert(['name' => 'İki']);
        $this->pushEvents($token, [$c1])->assertJsonPath('current_seq', 1);
        $this->pushEvents($token, [$c2])->assertJsonPath('current_seq', 2);

        // since=1 → yalnız ikinci değişiklik (seq 2).
        $delta = $this->pullSince($token, 1);
        $delta->assertJsonPath('mode', 'delta');
        $changes = $delta->json('changes');
        $this->assertCount(1, $changes);
        $this->assertSame(2, $changes[0]['seq']);
        $this->assertSame('customer', $changes[0]['entity_type']);
        $this->assertSame($c2['payload']['id'], $changes[0]['entity_id']);
        $delta->assertJsonPath('cursor', 2);
        $delta->assertJsonPath('has_more', false);
    }

    #[Test]
    public function lww_eski_occurred_at_reddedilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $id = (string) Str::uuid7();
        $t1 = now()->subMinutes(10)->toIso8601String();
        $t2 = now()->toIso8601String();

        // İlk oluşturma (t1), sonra t2 ile güncelleme (kazanır), sonra t1 ile tekrar (stale).
        $this->pushEvents($token, [$this->customerUpsert(['id' => $id, 'name' => 'Eski'], ['occurred_at' => $t1])]);
        $this->pushEvents($token, [$this->customerUpsert(['id' => $id, 'name' => 'Yeni'], ['occurred_at' => $t2])])
            ->assertJsonPath('results.0.status', 'applied');
        $stale = $this->pushEvents($token, [$this->customerUpsert(['id' => $id, 'name' => 'Daha Eski'], ['occurred_at' => $t1])]);

        $stale->assertJsonPath('results.0.status', 'stale');
        $stale->assertJsonPath('results.0.server_seq', null);

        $name = $this->asOwner(fn () => Customer::query()->find($id)?->name);
        $this->assertSame('Yeni', $name, 'LWW: eski occurred_at ismi ezmemeli.');
    }

    #[Test]
    public function lww_esit_occurred_atta_device_id_ile_ayrisir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $id = (string) Str::uuid7();
        $t = now()->toIso8601String();
        $lowDevice = '00000000-0000-7000-8000-000000000000';
        $highDevice = 'ffffffff-ffff-7fff-8fff-ffffffffffff';

        $this->pushEvents($token, [$this->customerUpsert(['id' => $id, 'name' => 'Düşük Cihaz'], ['occurred_at' => $t, 'device_id' => $lowDevice])]);
        // Aynı an, daha yüksek device_id → kazanır.
        $this->pushEvents($token, [$this->customerUpsert(['id' => $id, 'name' => 'Yüksek Cihaz'], ['occurred_at' => $t, 'device_id' => $highDevice])])
            ->assertJsonPath('results.0.status', 'applied');
        // Aynı an, daha düşük device_id → kaybeder (stale).
        $this->pushEvents($token, [$this->customerUpsert(['id' => $id, 'name' => 'Tekrar Düşük'], ['occurred_at' => $t, 'device_id' => $lowDevice])])
            ->assertJsonPath('results.0.status', 'stale');

        $name = $this->asOwner(fn () => Customer::query()->find($id)?->name);
        $this->assertSame('Yüksek Cihaz', $name);
    }

    #[Test]
    public function silme_tombstone_yazar_satiri_fiziksel_silmez(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Silinecek']);
        $id = $cust['payload']['id'];
        $this->pushEvents($token, [$cust])->assertJsonPath('current_seq', 1);

        $del = $this->customerDelete($id, ['occurred_at' => now()->addSecond()->toIso8601String()]);
        $this->pushEvents($token, [$del])->assertJsonPath('results.0.status', 'applied');

        // Delta: op=delete gelir.
        $delta = $this->pullSince($token, 1);
        $this->assertSame('delete', $delta->json('changes.0.op'));
        $this->assertSame($id, $delta->json('changes.0.entity_id'));

        // Snapshot tombstone'u göstermez; ama satır fiziksel olarak durur (deleted_at dolu).
        $snap = $this->pullSince($token, 0);
        $this->assertCount(0, $snap->json('entities.customer'));
        $row = $this->asOwner(fn () => Customer::query()->find($id));
        $this->assertNotNull($row, 'Silme fiziksel değildir — satır durur.');
        $this->assertNotNull($row->deleted_at);
    }

    #[Test]
    public function siparis_olusturma_siparis_satir_ve_olayi_senkronlar_total_hesaplar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // Önce müşteri, sonra ona sipariş (2 satır: 4500*2 + 6000*1 = 15000).
        $cust = $this->customerUpsert(['name' => 'Sipariş Müşterisi']);
        $this->pushEvents($token, [$cust]);
        $order = $this->orderCreated(
            [$this->line(['unit_price_kurus' => 4500, 'qty' => 2]), $this->line(['unit_price_kurus' => 6000, 'qty' => 1])],
            ['customer_id' => $cust['payload']['id']],
        );
        $orderId = $order['payload']['order']['id'];

        $response = $this->pushEvents($token, [$order]);
        $response->assertJsonPath('results.0.status', 'applied');

        // Sipariş önbelleği olaylardan türedi.
        $stored = $this->asOwner(fn () => Order::query()->find($orderId));
        $this->assertSame('open', $stored->status);
        $this->assertSame(15000, $stored->total_kurus);
        $lineCount = $this->asOwner(fn () => OrderLine::query()->where('order_id', $orderId)->count());
        $this->assertSame(2, $lineCount);

        // Snapshot: order + order_line + order_event birlikte gelir.
        $snap = $this->pullSince($token, 0);
        $this->assertCount(1, $snap->json('entities.order'));
        $this->assertCount(2, $snap->json('entities.order_line'));
        $this->assertCount(1, $snap->json('entities.order_event'));

        // Teslim et → status delivered, ödeme tipi işlenir.
        $deliver = $this->orderEvent('delivered', ['order_id' => $orderId, 'payment_type' => 'nakit']);
        $this->pushEvents($token, [$deliver])->assertJsonPath('results.0.status', 'applied');
        $delivered = $this->asOwner(fn () => Order::query()->find($orderId));
        $this->assertSame('delivered', $delivered->status);
        $this->assertSame('nakit', $delivered->payment_type);
    }

    #[Test]
    public function defter_kaydi_bakiye_onbellegini_defterden_yeniden_kurar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Veresiye Müşterisi']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // İki borç kaydı: 9000 + 6000 = 15000 (append-only; bakiye defterden türer).
        $this->pushEvents($token, [$this->ledgerEntry(['customer_id' => $customerId, 'amount_kurus' => 9000])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($token, [$this->ledgerEntry(['customer_id' => $customerId, 'amount_kurus' => 6000])]);

        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(15000, $balance);

        $entryCount = $this->asOwner(fn () => LedgerEntry::query()->where('customer_id', $customerId)->count());
        $this->assertSame(2, $entryCount);
    }

    #[Test]
    public function gecersiz_olay_reddedilir_diger_olaylar_uygulanir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // İlk olay geçerli (müşteri), ikinci olay geçersiz (var olmayan customer_id'ye telefon).
        $good = $this->customerUpsert(['name' => 'Geçerli']);
        $bad = $this->event('customer_phone', 'upsert', [
            'id' => (string) Str::uuid7(),
            'customer_id' => (string) Str::uuid7(), // yok
            'phone_e164' => '+905321112233',
        ]);

        $response = $this->pushEvents($token, [$good, $bad]);
        $response->assertOk();
        $response->assertJsonPath('results.0.status', 'applied');
        $response->assertJsonPath('results.1.status', 'rejected');

        // Geçerli olay uygulandı; parti reddedilen olay yüzünden bozulmadı.
        $count = $this->asOwner(fn () => Customer::query()->count());
        $this->assertSame(1, $count);
    }

    #[Test]
    public function ayni_client_event_id_partisi_uc_kez_tekrarlanirsa_tek_kez_uygulanir_seq_sabit_kalir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // İki olaylık bir parti (müşteri + ürün) — retry senaryosu: ağ zaman aşımı yüzünden
        // istemci "gönderdim mi acaba" bilmez, aynı partiyi 3 kez tekrar gönderir.
        $batch = [
            $this->customerUpsert(['name' => 'Parti Müşterisi']),
            $this->event('product', 'upsert', [
                'id' => (string) Str::uuid7(), 'name' => 'Parti Ürünü', 'unit_price_kurus' => 2000,
            ]),
        ];

        $first = $this->pushEvents($token, $batch);
        $first->assertJsonPath('results.0.status', 'applied');
        $first->assertJsonPath('results.1.status', 'applied');
        $first->assertJsonPath('current_seq', 2);

        foreach (range(1, 2) as $_) {
            $retry = $this->pushEvents($token, $batch);
            $retry->assertJsonPath('results.0.status', 'duplicate');
            $retry->assertJsonPath('results.1.status', 'duplicate');
            $retry->assertJsonPath('results.0.server_seq', 1);
            $retry->assertJsonPath('results.1.server_seq', 2);
            $retry->assertJsonPath('current_seq', 2); // seq İLERLEMEDİ
        }

        $this->assertSame(1, $this->asOwner(fn () => Customer::query()->count()));
        $this->assertSame(1, $this->asOwner(fn () => Product::query()->count()));

        // Delta akışında da tekrarlanan partiden dolayı fazladan satır yok — yalnız 2 değişiklik.
        $delta = $this->pullSince($token, 0);
        $this->assertCount(1, $delta->json('entities.customer'));
        $this->assertCount(1, $delta->json('entities.product'));
    }

    #[Test]
    public function siparis_olay_akisi_created_satir_ekle_satir_sil_teslim_iptal_sirasi_dogru_turer(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $order = $this->orderCreated([$this->line(['unit_price_kurus' => 1000, 'qty' => 1])]);
        $orderId = $order['payload']['order']['id'];
        $this->pushEvents($token, [$order])->assertJsonPath('results.0.status', 'applied');

        $extraLine = $this->line(['unit_price_kurus' => 500, 'qty' => 2]); // +1000
        $this->pushEvents($token, [$this->event('order', 'line_added', ['order_id' => $orderId, 'line' => $extraLine])])
            ->assertJsonPath('results.0.status', 'applied');
        $afterAdd = $this->asOwner(fn () => Order::query()->find($orderId));
        $this->assertSame(2000, $afterAdd->total_kurus, 'created(1000) + line_added(1000) = 2000');

        $this->pushEvents($token, [$this->event('order', 'line_removed', ['order_id' => $orderId, 'line_id' => $extraLine['id']])])
            ->assertJsonPath('results.0.status', 'applied');
        $afterRemove = $this->asOwner(fn () => Order::query()->find($orderId));
        $this->assertSame(1000, $afterRemove->total_kurus, 'eklenen satır silinince toplam geri düşer');

        $this->pushEvents($token, [$this->orderEvent('delivered', ['order_id' => $orderId, 'payment_type' => 'nakit'])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertSame('delivered', $this->asOwner(fn () => Order::query()->find($orderId)->status));

        // Teslim edildikten SONRA iptal gelirse (nadir ama olası bir düzeltme akışı) — cancelled kazanır.
        $this->pushEvents($token, [$this->orderEvent('cancelled', ['order_id' => $orderId])])
            ->assertJsonPath('results.0.status', 'applied');
        $final = $this->asOwner(fn () => Order::query()->find($orderId));
        $this->assertSame('cancelled', $final->status, 'cancelled, delivered\'dan SONRA gelse bile kazanmalı (recomputeOrder önceliği).');

        // Tüm olaylar (created, line_added, line_removed, delivered, cancelled) sırayla günlüklendi.
        $eventTypes = $this->asOwner(fn () => OrderEvent::query()
            ->where('order_id', $orderId)->orderBy('created_at')->pluck('event_type')->all());
        $this->assertSame(['created', 'line_added', 'line_removed', 'delivered', 'cancelled'], $eventTypes);
    }

    #[Test]
    public function iki_cihaz_ayni_musteriyi_duzenler_son_yazan_kazanir_ve_defter_iki_kaydi_birlestirir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']); // aynı tenant, aynı kullanıcı — iki FARKLI cihaz simülasyonu

        $deviceKurye = (string) Str::uuid7();
        $devicePatron = (string) Str::uuid7();
        $customerId = (string) Str::uuid7();
        $t0 = now()->subMinutes(5)->toIso8601String();
        $t1 = now()->subMinutes(3)->toIso8601String();
        $t2 = now()->toIso8601String();

        // Kurye cihazı offline'ken müşteriyi oluşturur (t0).
        $this->pushEvents($token, [$this->customerUpsert(
            ['id' => $customerId, 'name' => 'Kurye Kaydı'],
            ['occurred_at' => $t0, 'device_id' => $deviceKurye]
        )])->assertJsonPath('results.0.status', 'applied');

        // Patron cihazı, farklı bir anda (t1) aynı müşterinin adını düzeltir — daha yeni, kazanır.
        $this->pushEvents($token, [$this->customerUpsert(
            ['id' => $customerId, 'name' => 'Patron Düzeltmesi'],
            ['occurred_at' => $t1, 'device_id' => $devicePatron]
        )])->assertJsonPath('results.0.status', 'applied');

        // Kurye cihazı gecikmeli senkronla eski (t0 sonrası ama t1'den ESKİ) bir düzenleme daha yollar
        // — sunucudaki t1'den eski olduğu için stale (kaybeder), patron'un ismi ezilmez.
        $tGecikmisKurye = now()->subMinutes(4)->toIso8601String(); // t0 < tGecikmisKurye < t1
        $this->pushEvents($token, [$this->customerUpsert(
            ['id' => $customerId, 'name' => 'Kurye Gecikmiş Yazim'],
            ['occurred_at' => $tGecikmisKurye, 'device_id' => $deviceKurye]
        )])->assertJsonPath('results.0.status', 'stale');

        $final = $this->asOwner(fn () => Customer::query()->find($customerId));
        $this->assertSame('Patron Düzeltmesi', $final->name, 'İki cihaz çakıştığında son yazan (t1) kazanmalı.');

        // Defter tarafında ÇAKIŞMA yok, BİRLEŞME var: iki cihaz da aynı müşteriye borç düşer,
        // ikisi de kalıcı kayıt olarak durur, bakiye ikisinin toplamı olur.
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'amount_kurus' => 9000,
        ], ['occurred_at' => $t1, 'device_id' => $deviceKurye])])->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'amount_kurus' => 6000,
        ], ['occurred_at' => $t2, 'device_id' => $devicePatron])])->assertJsonPath('results.0.status', 'applied');

        $entries = $this->asOwner(fn () => LedgerEntry::query()->where('customer_id', $customerId)->get());
        $this->assertCount(2, $entries, 'Defter kayıtları çakışmaz, İKİSİ de kalıcı durur (append-only).');
        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(15000, $balance, 'Bakiye iki cihazın defter kayıtlarının TOPLAMI olmalı.');
    }

    #[Test]
    public function kupon_kullanimi_bakiyeyi_eksiye_dusurebilir_reddedilmez(): void
    {
        // DECISIONS: iki cihaz offline'ken aynı son kuponu harcayabilir; teslim edilmiş mal
        // gerçektir, sistem reddedemez — kupon bakiyesi eksiye düşer, correction hareketiyle kapatılır.
        // FAZ 3: kupon ADETtir (coupon_movements), PARA değil — para tarafı normal debit+payment ile.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Kupon Müşterisi']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // 1 adet kupon hakkı (grant +1), iki cihaz OFFLINE'ken aynı son hakkı harcar (use -1 iki kez).
        $this->pushEvents($token, [$this->couponMovement('grant', ['customer_id' => $customerId, 'qty_delta' => 1])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($token, [$this->couponMovement('use', ['customer_id' => $customerId])])
            ->assertJsonPath('results.0.status', 'applied');
        $second = $this->pushEvents($token, [$this->couponMovement('use', ['customer_id' => $customerId])]);
        $second->assertJsonPath('results.0.status', 'applied', 'İkinci cihazın kupon harcaması da KABUL edilmeli — reddedilmez.');

        // Bakiye önbelleği (coupon_balances) defterden türer, eksiye düşer.
        $balance = $this->asOwner(fn () => CouponBalance::query()->where('customer_id', $customerId)->value('balance_qty'));
        $this->assertSame(-1, $balance, 'Kupon bakiyesi eksiye düşebilir (DECISIONS); düzeltme sonraki correction hareketiyle.');

        $moveCount = $this->asOwner(fn () => CouponMovement::query()->where('customer_id', $customerId)->count());
        $this->assertSame(3, $moveCount, 'Üç hareket de append-only durur; hiçbiri silinmez/ezilmez.');
    }

    #[Test]
    public function pesin_satis_cift_satir_uretir_net_borc_sifir_kasa_dolu(): void
    {
        // DECISIONS Faz 3 çift-satır: peşin/kart satış debit(+total) + payment(−total) → net borç 0,
        // para kasada (payment payment_type ile). Veresiye yalnız debit; sonradan tahsilat yalnız payment.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Peşin Müşteri']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // Peşin nakit satış: debit +9000 ve payment −9000 (nakit).
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'debit', 'amount_kurus' => 9000,
        ])])->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'payment', 'amount_kurus' => -9000, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'applied');

        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(0, $balance, 'Peşin satış net borcu 0 bırakır (debit+payment).');

        // Kasa = payment toplamı (ödeme tipine göre). Ciro = debit toplamı.
        $kasaNakit = $this->asOwner(fn () => (int) LedgerEntry::query()
            ->where('customer_id', $customerId)->where('payment_type', 'nakit')->sum('amount_kurus'));
        $this->assertSame(-9000, $kasaNakit, 'Kasaya 9000 nakit girdi (payment negatif).');
    }

    #[Test]
    public function defter_isaret_dogrulamasi_yanlis_isareti_reddeder(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'İşaret Müşteri']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // debit NEGATİF → rejected (borç artışı ≥ 0 olmalı).
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'debit', 'amount_kurus' => -100,
        ])])->assertJsonPath('results.0.status', 'rejected');

        // payment POZİTİF → rejected (borç azalışı ≤ 0 olmalı).
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'payment', 'amount_kurus' => 100, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'rejected');

        // payment_type payment DIŞINDA → rejected.
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'debit', 'amount_kurus' => 100, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'rejected');

        // Hiçbiri uygulanmadı; bakiye 0 kaldı (yalnızca müşteri var).
        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(0, $balance);
    }

    #[Test]
    public function correction_payment_type_tasiyabilir_kasa_ve_bakiye_birlikte_duzelir(): void
    {
        // DECISIONS Faz 3: yanlış tahsilatı ters çeviren correction, payment'ın payment_type'ını
        // taşır → hem bakiye hem kasa (payment_type IS NOT NULL toplamı) net 0'a döner.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $cust = $this->customerUpsert(['name' => 'Düzeltme Müşteri']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // Yanlış nakit tahsilat: payment(−5000, nakit).
        $pay = $this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'payment', 'amount_kurus' => -5000, 'payment_type' => 'nakit',
        ]);
        $this->pushEvents($token, [$pay])->assertJsonPath('results.0.status', 'applied');

        // Ters çeviren correction AYNI payment_type'ı taşır — KABUL edilmeli (debit/credit'te YASAK olurdu).
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'correction', 'amount_kurus' => 5000,
            'payment_type' => 'nakit', 'reverses_entry_id' => $pay['payload']['id'],
        ])])->assertJsonPath('results.0.status', 'applied');

        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(0, $balance, 'payment −5000 + correction +5000 = 0');

        // Kasa = payment_type IS NOT NULL kayıtların toplamı → net 0.
        $kasa = $this->asOwner(fn () => (int) LedgerEntry::query()
            ->whereNotNull('payment_type')->sum('amount_kurus'));
        $this->assertSame(0, $kasa, 'correction payment_type taşıdı → kasa da net 0');
    }

    #[Test]
    public function correction_payment_type_yalniz_payment_ve_correctionda_kabul_edilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $cust = $this->customerUpsert(['name' => 'İşaret']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // debit + payment_type → hâlâ rejected (satış hesaba yazılır, nakde dokunmaz).
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'debit', 'amount_kurus' => 100, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'rejected');

        // credit + payment_type → de rejected (manuel alacak/indirim kasaya dokunmaz; kapı B'de
        // gevşetilirken yalnız payment+correction'a açıldı, credit HÂLÂ dışarıda kalmalı).
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'credit', 'amount_kurus' => -100, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'rejected');

        $count = $this->asOwner(fn () => LedgerEntry::query()->where('customer_id', $customerId)->count());
        $this->assertSame(0, $count, 'İki geçersiz kayıt da uygulanmamalı (payment_type sınırı korunur).');
    }

    #[Test]
    public function kupon_satisi_ve_kullanimi_bakiye_ve_snapshot_dogru(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Paket Müşteri']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // 5'lik paket satışı: kupon grant +5 (+ paranın parası ayrı debit/payment ile, burada yalnız adet).
        $this->pushEvents($token, [$this->couponMovement('grant', ['customer_id' => $customerId, 'qty_delta' => 5])])
            ->assertJsonPath('results.0.status', 'applied');
        // İki teslimatta 2 kupon kullanıldı.
        $this->pushEvents($token, [$this->couponMovement('use', ['customer_id' => $customerId])]);
        $this->pushEvents($token, [$this->couponMovement('use', ['customer_id' => $customerId])]);

        $balance = $this->asOwner(fn () => CouponBalance::query()->where('customer_id', $customerId)->value('balance_qty'));
        $this->assertSame(3, $balance, '5 verildi, 2 kullanıldı → 3 kaldı.');

        // Snapshot iki yeni tabloyu da taşır.
        $snap = $this->pullSince($token, 0);
        $this->assertCount(3, $snap->json('entities.coupon_movement'));
        $this->assertCount(1, $snap->json('entities.coupon_balance'));
        $this->assertSame(3, $snap->json('entities.coupon_balance.0.balance_qty'));
    }

    #[Test]
    public function kupon_hareketi_ayni_client_event_id_ile_tekrarlanirsa_bakiye_ikizlenmez(): void
    {
        // Idempotency (DECISIONS): ağ zaman aşımı sonrası aynı kupon 'use' birden çok kez gönderilir.
        // İkinci+ gönderim duplicate döner ve bakiye TEKRAR düşmez (korku #2: defter ikizlenmemeli).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Kupon Idempotent']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);
        $this->pushEvents($token, [$this->couponMovement('grant', ['customer_id' => $customerId, 'qty_delta' => 3])]);

        // Sabit client_event_id taşıyan tek bir 'use' olayı — üç kez gönderilir.
        $use = $this->couponMovement('use', ['customer_id' => $customerId]);
        $this->pushEvents($token, [$use])->assertJsonPath('results.0.status', 'applied');
        foreach (range(1, 2) as $_) {
            $this->pushEvents($token, [$use])->assertJsonPath('results.0.status', 'duplicate');
        }

        $balance = $this->asOwner(fn () => CouponBalance::query()->where('customer_id', $customerId)->value('balance_qty'));
        $this->assertSame(2, $balance, 'Retry bakiyeyi tekrar düşürmemeli: 3 grant − 1 use = 2.');
        $moveCount = $this->asOwner(fn () => CouponMovement::query()->where('customer_id', $customerId)->count());
        $this->assertSame(2, $moveCount, 'Retry yeni hareket eklememeli (grant + tek use).');
    }

    #[Test]
    public function bozulan_bakiye_onbellegi_sonraki_defter_kaydiyla_defterden_yeniden_kurulur(): void
    {
        // DECISIONS: "önbellek bozulursa defterden yeniden kurulur". Bakiye kasıtlı bozulur; sonraki
        // ledger kaydı SUM'ı BAŞTAN hesapladığından bakiye gerçek toplama döner (bozuk+delta DEĞİL).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Bozuk Bakiye']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'debit', 'amount_kurus' => 10000,
        ])]);

        // Önbelleği kasıtlı boz (owner ile — istemci balance_kurus yazamaz, bu bir simülasyon).
        $this->asOwner(fn () => Customer::query()->whereKey($customerId)->update(['balance_kurus' => 999999]));

        // Yeni kayıt +5000: sunucu SUM'ı defterden kurar → 15000 (999999+5000 DEĞİL).
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'debit', 'amount_kurus' => 5000,
        ])])->assertJsonPath('results.0.status', 'applied');

        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(15000, $balance, 'Bozuk önbellek deltaya değil, defterin gerçek toplamına düzelmeli.');
        $trueSum = $this->asOwner(fn () => (int) LedgerEntry::query()->where('customer_id', $customerId)->sum('amount_kurus'));
        $this->assertSame($trueSum, $balance, 'balance_kurus birebir SUM(ledger_entries.amount_kurus) olmalı.');
    }

    #[Test]
    public function bozulan_kupon_bakiyesi_sonraki_hareketle_harekelerden_yeniden_kurulur(): void
    {
        // coupon_balances de önbellek: bozulursa bir sonraki hareket SUM(qty_delta) ile onarır.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Bozuk Kupon']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);
        $this->pushEvents($token, [$this->couponMovement('grant', ['customer_id' => $customerId, 'qty_delta' => 5])]);

        $this->asOwner(fn () => CouponBalance::query()->where('customer_id', $customerId)->update(['balance_qty' => 999]));

        // use −1: SUM harekelerden = 4 (999−1 DEĞİL).
        $this->pushEvents($token, [$this->couponMovement('use', ['customer_id' => $customerId])])
            ->assertJsonPath('results.0.status', 'applied');

        $balance = $this->asOwner(fn () => CouponBalance::query()->where('customer_id', $customerId)->value('balance_qty'));
        $this->assertSame(4, $balance, 'Bozuk kupon önbelleği harekelerin gerçek toplamına düzelmeli.');
    }

    #[Test]
    public function ledger_ters_kaydi_yanlis_borcu_kapatir_kaynak_kayit_durur(): void
    {
        // BRIEF/DECISIONS: düzeltme yalnız ters kayıtla; kaynak kayıt kanıt olarak durur (silinmez).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Ters Kayıt']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        $hatali = $this->ledgerEntry(['customer_id' => $customerId, 'entry_type' => 'debit', 'amount_kurus' => 10000]);
        $hataliId = $hatali['payload']['id'];
        $this->pushEvents($token, [$hatali])->assertJsonPath('results.0.status', 'applied');

        // Ters kayıt: correction −10000, reverses_entry_id = hatalı kaydın id'si.
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'correction',
            'amount_kurus' => -10000, 'reverses_entry_id' => $hataliId,
        ])])->assertJsonPath('results.0.status', 'applied');

        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(0, $balance, 'debit +10000 + correction −10000 = 0.');
        $count = $this->asOwner(fn () => LedgerEntry::query()->where('customer_id', $customerId)->count());
        $this->assertSame(2, $count, 'Kaynak kayıt silinmez; düzeltme yeni satır olarak durur (append-only).');
        $reverses = $this->asOwner(fn () => LedgerEntry::query()->where('entry_type', 'correction')->value('reverses_entry_id'));
        $this->assertSame($hataliId, $reverses, 'Ters kayıt düzelttiği satıra bağlı olmalı (kanıt zinciri).');
    }

    #[Test]
    public function kupon_ters_hareketi_eksi_bakiyeyi_kapatir_kaynak_hareket_durur(): void
    {
        // Eksi kupon bakiyesi correction hareketiyle kapatılır (DECISIONS: düzeltme kaydıyla kapanır).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Kupon Ters']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // 1 hak, iki kullanım → −1 (iki cihaz aynı son kuponu harcadı).
        $this->pushEvents($token, [$this->couponMovement('grant', ['customer_id' => $customerId, 'qty_delta' => 1])]);
        $this->pushEvents($token, [$this->couponMovement('use', ['customer_id' => $customerId])]);
        $this->pushEvents($token, [$this->couponMovement('use', ['customer_id' => $customerId])]);

        $reverses = $this->asOwner(fn () => CouponMovement::query()->where('movement_type', 'use')->value('id'));
        // correction +1 → 0 (bir kullanımı ters çevirir).
        $this->pushEvents($token, [$this->couponMovement('correction', [
            'customer_id' => $customerId, 'qty_delta' => 1, 'reverses_movement_id' => $reverses,
        ])])->assertJsonPath('results.0.status', 'applied');

        $balance = $this->asOwner(fn () => CouponBalance::query()->where('customer_id', $customerId)->value('balance_qty'));
        $this->assertSame(0, $balance, 'grant 1 − use 2 + correction 1 = 0.');
        $count = $this->asOwner(fn () => CouponMovement::query()->where('customer_id', $customerId)->count());
        $this->assertSame(4, $count, 'Dört hareket de append-only durur, hiçbiri silinmez/ezilmez.');
    }
}
