<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * Müşteri yaşam döngüsü: SİLME (tombstone + telefon/adres yayılması) ve KARA LİSTE.
 *
 * İkisi AYRI kavramdır ve bu testlerin işi tam olarak onları ayrı tutmaktır: silinen müşteri
 * listeden düşer, kara listedeki müşteri listede KALIR. Birinin diğerine sızması (ör. kara
 * listeye almanın müşteriyi gizlemesi) bayinin borç takibini kör eder.
 *
 * Tombstone'un kendisi SyncTest'te kanıtlanıyor; burada silmenin SONUÇLARI var.
 */
class CustomerLifecycleTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function musteri_silinince_telefon_ve_adresleri_de_tombstone_olur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Silinecek Müşteri']);
        $cid = $cust['payload']['id'];
        $phoneId = (string) Str::uuid7();
        $addressId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $cust,
            $this->event('customer_phone', 'upsert', [
                'id' => $phoneId, 'customer_id' => $cid, 'phone_e164' => '+905321112233',
            ]),
            $this->event('customer_address', 'upsert', [
                'id' => $addressId, 'customer_id' => $cid, 'address_text' => 'Kepez Mah. 1. Sok.',
            ]),
        ])->assertOk();

        $this->pushEvents($token, [
            $this->customerDelete($cid, ['occurred_at' => now()->addSecond()->toIso8601String()]),
        ])->assertJsonPath('results.0.status', 'applied');

        // Arayan tanıma customer_phones üzerinden çalışır ve müşteri satırına bakmaz: telefon
        // canlı kalsaydı silinen müşteri gelen aramada kartıyla çıkmaya devam ederdi.
        $phone = $this->asOwner(fn () => CustomerPhone::query()->find($phoneId));
        $this->assertNotNull($phone->deleted_at, 'Silinen müşterinin telefonu canlı kalamaz.');
        $address = $this->asOwner(fn () => CustomerAddress::query()->find($addressId));
        $this->assertNotNull($address->deleted_at);

        // Yeni kurulan cihaz öksüz satır görmemeli.
        $snap = $this->pullSince($token, 0);
        $this->assertCount(0, $snap->json('entities.customer'));
        $this->assertCount(0, $snap->json('entities.customer_phone'));
        $this->assertCount(0, $snap->json('entities.customer_address'));
    }

    #[Test]
    public function silme_deltasi_musteriyi_ve_cocuklarini_tek_partide_yayinlar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Delta Müşterisi']);
        $cid = $cust['payload']['id'];
        $this->pushEvents($token, [
            $cust,
            $this->event('customer_phone', 'upsert', [
                'id' => (string) Str::uuid7(), 'customer_id' => $cid, 'phone_e164' => '+905321119988',
            ]),
        ])->assertOk();

        $oncekiSeq = $this->pullSince($token, 0)->json('current_seq');

        $this->pushEvents($token, [
            $this->customerDelete($cid, ['occurred_at' => now()->addSecond()->toIso8601String()]),
        ])->assertOk();

        // İkinci cihaz yalnız delta çeker; telefonun silindiğini BURADAN öğrenmeli.
        $changes = collect($this->pullSince($token, $oncekiSeq)->json('changes'));
        $this->assertSame(2, $changes->count(), 'Silme müşteri + telefon değişikliği üretmeli.');
        $this->assertTrue($changes->every(fn ($c) => $c['op'] === 'delete'));
        $this->assertEqualsCanonicalizing(
            ['customer', 'customer_phone'],
            $changes->pluck('entity_type')->all()
        );
    }

    #[Test]
    public function zaten_silinmis_cocuk_satir_yeniden_degisiklik_uretmez(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Tekrar Silinen']);
        $cid = $cust['payload']['id'];
        $phoneId = (string) Str::uuid7();
        $this->pushEvents($token, [
            $cust,
            $this->event('customer_phone', 'upsert', [
                'id' => $phoneId, 'customer_id' => $cid, 'phone_e164' => '+905321117766',
            ]),
        ])->assertOk();

        // Telefon önce tek başına silinsin, sonra müşteri silinsin.
        $this->pushEvents($token, [
            $this->event('customer_phone', 'delete', ['id' => $phoneId],
                ['occurred_at' => now()->addSecond()->toIso8601String()]),
        ])->assertJsonPath('results.0.status', 'applied');

        $oncekiSeq = $this->pullSince($token, 0)->json('current_seq');

        $this->pushEvents($token, [
            $this->customerDelete($cid, ['occurred_at' => now()->addSeconds(2)->toIso8601String()]),
        ])->assertOk();

        $changes = collect($this->pullSince($token, $oncekiSeq)->json('changes'));
        $this->assertSame(1, $changes->count(), 'Zaten silinmiş telefon ikinci kez yayınlanmamalı.');
        $this->assertSame('customer', $changes->first()['entity_type']);
    }

    #[Test]
    public function kara_listeye_alma_musteriyi_listede_birakir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Kara Listelik']);
        $cid = $cust['payload']['id'];
        $this->pushEvents($token, [$cust])->assertOk();

        $damga = now()->addSecond();
        $this->pushEvents($token, [
            $this->customerUpsert(
                ['id' => $cid, 'name' => 'Kara Listelik', 'blacklisted_at' => $damga->toIso8601String()],
                ['occurred_at' => $damga->toIso8601String()],
            ),
        ])->assertJsonPath('results.0.status', 'applied');

        $row = $this->asOwner(fn () => Customer::query()->find($cid));
        $this->assertNotNull($row->blacklisted_at);
        $this->assertNull($row->deleted_at, 'Kara liste SİLME DEĞİLDİR.');

        // Kırmızı çizgi: kara listedeki müşteri listeden düşmez — bayi borcunu takip etmeli.
        $snap = $this->pullSince($token, 0);
        $musteriler = collect($snap->json('entities.customer'));
        $this->assertCount(1, $musteriler);
        $this->assertNotNull($musteriler->first()['blacklisted_at']);
    }

    #[Test]
    public function kara_listeden_cikarma_alani_bosaltir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Affedilen']);
        $cid = $cust['payload']['id'];
        $this->pushEvents($token, [$cust])->assertOk();

        $this->pushEvents($token, [
            $this->customerUpsert(
                ['id' => $cid, 'name' => 'Affedilen', 'blacklisted_at' => now()->addSecond()->toIso8601String()],
                ['occurred_at' => now()->addSecond()->toIso8601String()],
            ),
        ])->assertOk();

        // Çıkarma = alanı null göndermek (ayrı op yok; LWW aynı alanı yönetir).
        $this->pushEvents($token, [
            $this->customerUpsert(
                ['id' => $cid, 'name' => 'Affedilen', 'blacklisted_at' => null],
                ['occurred_at' => now()->addSeconds(2)->toIso8601String()],
            ),
        ])->assertJsonPath('results.0.status', 'applied');

        $row = $this->asOwner(fn () => Customer::query()->find($cid));
        $this->assertNull($row->blacklisted_at);
    }

    #[Test]
    public function kara_liste_lww_ile_cozulur_eski_olay_uygulanmaz(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Çakışan']);
        $cid = $cust['payload']['id'];
        $this->pushEvents($token, [$cust])->assertOk();

        $yeni = now()->addSeconds(10);
        $this->pushEvents($token, [
            $this->customerUpsert(
                ['id' => $cid, 'name' => 'Çakışan', 'blacklisted_at' => $yeni->toIso8601String()],
                ['occurred_at' => $yeni->toIso8601String()],
            ),
        ])->assertJsonPath('results.0.status', 'applied');

        // Çevrimdışı kalmış ikinci cihaz "kara listeden çıkar" diyor ama damgası ESKİ.
        $this->pushEvents($token, [
            $this->customerUpsert(
                ['id' => $cid, 'name' => 'Çakışan', 'blacklisted_at' => null],
                ['occurred_at' => now()->addSeconds(5)->toIso8601String()],
            ),
        ])->assertJsonPath('results.0.status', 'stale');

        $row = $this->asOwner(fn () => Customer::query()->find($cid));
        $this->assertNotNull($row->blacklisted_at, 'Eski olay kara listeyi kaldıramaz.');
    }

    #[Test]
    public function silme_ve_kara_liste_kiraci_sinirini_asamaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $tokenA = $this->tokenFor($a['patron']);
        $tokenB = $this->tokenFor($b['patron']);

        $cust = $this->customerUpsert(['name' => 'A Bayisinin Müşterisi']);
        $cid = $cust['payload']['id'];
        $this->pushEvents($tokenA, [$cust])->assertOk();

        // B bayisi A'nın müşterisini SİLEMEZ: RLS altında satır görünmez → yeni satır DOĞMAZ,
        // A'nınki dokunulmaz kalır.
        $this->pushEvents($tokenB, [
            $this->customerDelete($cid, ['occurred_at' => now()->addSecond()->toIso8601String()]),
        ])->assertJsonPath('results.0.status', 'noop');

        $row = $this->asOwner(fn () => Customer::query()->find($cid));
        $this->assertNull($row->deleted_at, 'Başka bayi silemez (kırmızı çizgi #1).');
        $this->assertSame($a['tenant']->id, $row->tenant_id);

        // Kara listeye alma denemesi: RLS altında satır görünmediği için B YENİ satır yazmaya
        // çalışır, ama customers.id GLOBAL birincil anahtardır → 23505 ile reddedilir. Sonuç
        // aynı kapıya çıkar: A'nın satırı dokunulmaz.
        $this->pushEvents($tokenB, [
            $this->customerUpsert(
                ['id' => $cid, 'name' => 'Sızmaya Çalışan', 'blacklisted_at' => now()->addSeconds(2)->toIso8601String()],
                ['occurred_at' => now()->addSeconds(2)->toIso8601String()],
            ),
        ])->assertJsonPath('results.0.status', 'rejected');

        $row = $this->asOwner(fn () => Customer::query()->where('tenant_id', $a['tenant']->id)->find($cid));
        $this->assertSame('A Bayisinin Müşterisi', $row->name);
        $this->assertNull($row->blacklisted_at);
    }
}
