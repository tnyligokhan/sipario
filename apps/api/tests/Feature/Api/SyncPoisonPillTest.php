<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Support\Sync\SyncService;
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * ZEHİRLİ HAP — sahada yaşanmış arızanın regresyon kilidi (2026-08-05).
 *
 * ARIZA: outbox'ta sunucunun artık kabul etmediği TEK bir olay bulunan telefon KALICI ÇEVRİMDIŞI
 * kalıyordu. Zincir dört halkaydı: (1) `SyncPushRequest` olay içeriğini PARTİ düzeyinde doğruluyor,
 * (2) tek bozuk olay tüm isteği 422 yapıyor, (3) istemci 422'de hiçbir olayı işaretlemiyor
 * (`sync_engine.dart` `api.push()` fırlatınca outbox'a dokunmaz), (4) sonraki tur AYNI partiyi
 * yolluyor → aynı 422 → sonsuza kadar. Kuyruk asla boşalmıyordu ve tek çözüm uygulama verisini
 * temizlemekti — ki bu outbox'ı da siler, yani gönderilmemiş sipariş/tahsilat KAYBOLUR
 * (BRIEF kırmızı çizgi #3: "hiçbir kayıt kaybolmaz" ihlali).
 *
 * Bu dosya ayrımı kilitler: ZARF hatası 422 (protokol), OLAY İÇERİĞİ hatası per-olay 'rejected'
 * (parti 200 ile akar). Buradaki testler kırmızıya dönerse telefonlar yeniden kilitlenir.
 */
class SyncPoisonPillTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function desteklenmeyen_kupon_olayi_kuyrugu_kalici_kilitlemez(): void
    {
        // SAHA VAKASI: `coupon` 2026-07-26'da entity_type listesinden çıkarıldı. O gün kuyruğunda
        // bir kupon olayı kalmış her cihaz, gönderilmeyi bekleyen TÜM siparişleriyle birlikte
        // kilitlendi — sunucu partinin tamamını 422'liyordu, istemci hiçbir satırı işaretleyemiyordu.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $kupon = $this->event('coupon', 'grant', ['id' => (string) Str::uuid7(), 'amount_kurus' => 500]);
        $musteri = $this->customerUpsert(['name' => 'Kuyruktaki Müşteri']);

        $yanit = $this->pushEvents($token, [$kupon, $musteri]);

        $yanit->assertOk(); // 422 DEĞİL: parti akmalı.
        $yanit->assertJsonPath('results.0.status', 'rejected');
        $yanit->assertJsonPath('results.0.reason', 'unknown_entity_type');
        $yanit->assertJsonPath('results.0.client_event_id', $kupon['client_event_id']);
        $yanit->assertJsonPath('results.1.status', 'applied');
        $yanit->assertJsonPath('current_seq', 1); // reddedilen olay seq YAKMAZ

        $this->assertSame(1, $this->asOwner(fn () => Customer::query()->count()),
            'Kupon olayının reddi, aynı partideki müşteri kaydını engellememeli.');

        // Kuyruk AKABİLİR: istemci reddedileni karantinaya alır, kalanını acked yapar. Aynı parti
        // yeniden gelse bile (retry) sunucu yine 200 döner — kupon 'rejected', müşteri 'duplicate'.
        $tekrar = $this->pushEvents($token, [$kupon, $musteri]);
        $tekrar->assertOk();
        $tekrar->assertJsonPath('results.0.status', 'rejected');
        $tekrar->assertJsonPath('results.1.status', 'duplicate');
    }

    #[Test]
    public function parti_icindeki_tek_bozuk_olay_digerlerini_dusurmez(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $once = $this->customerUpsert(['name' => 'Önceki']);
        $bozuk = $this->event('gizemli_varlik', 'upsert', ['id' => (string) Str::uuid7()]);
        $sonra = $this->customerUpsert(['name' => 'Sonraki']);

        $yanit = $this->pushEvents($token, [$once, $bozuk, $sonra]);

        $yanit->assertOk();
        $yanit->assertJsonPath('results.0.status', 'applied');
        $yanit->assertJsonPath('results.1.status', 'rejected');
        $yanit->assertJsonPath('results.1.reason', 'unknown_entity_type');
        $yanit->assertJsonPath('results.2.status', 'applied');
        $yanit->assertJsonPath('current_seq', 2);

        // Sıralama PHP tarafında yapılır: Postgres'in `ORDER BY name` sonucu collation'a bağlıdır
        // ('Ö' harfi C ile en_US arasında yer değiştirir) ve bu testin konusu sıralama değildir.
        $adlar = $this->asOwner(fn () => Customer::query()->pluck('name')->all());
        sort($adlar);
        $this->assertSame(['Sonraki', 'Önceki'], $adlar,
            'Bozuk olay ORTADA olsa bile kendisinden sonraki olay uygulanmalı.');
    }

    #[Test]
    public function bozuk_op_payload_tarih_ve_cihaz_kimligi_olay_bazinda_reddedilir(): void
    {
        // Dördü BİR partide: eskiden bu isteğin tamamı 422'ydi ve beşinci (sağlam) olay da yanardı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $bozukOp = $this->event('customer', 'kaydet', ['id' => (string) Str::uuid7(), 'name' => 'X']);

        $bozukPayload = $this->customerUpsert();
        $bozukPayload['payload'] = 'dizi-degil';

        $bozukTarih = $this->customerUpsert();
        $bozukTarih['occurred_at'] = 'dun-aksam';

        $bozukCihaz = $this->customerUpsert();
        $bozukCihaz['device_id'] = 'cihaz-1';

        $saglam = $this->customerUpsert(['name' => 'Sağlam']);

        $yanit = $this->pushEvents($token, [$bozukOp, $bozukPayload, $bozukTarih, $bozukCihaz, $saglam]);

        $yanit->assertOk();
        $yanit->assertJsonPath('results.0.reason', 'unknown_op');
        $yanit->assertJsonPath('results.1.reason', 'invalid_payload');
        $yanit->assertJsonPath('results.2.reason', 'invalid_occurred_at');
        $yanit->assertJsonPath('results.3.reason', 'invalid_device_id');
        $yanit->assertJsonPath('results.4.status', 'applied');
        $yanit->assertJsonPath('results.4.reason', null);

        foreach ([0, 1, 2, 3] as $i) {
            $yanit->assertJsonPath("results.{$i}.status", 'rejected');
            $yanit->assertJsonPath("results.{$i}.server_seq", null);
        }

        $this->assertSame(1, $this->asOwner(fn () => Customer::query()->count()));
    }

    #[Test]
    public function gecersiz_client_event_id_ham_degeriyle_geri_yansitilir(): void
    {
        // İstemci sonuçları client_event_id ile eşler (sync_engine `byId`). Kimliği normalize
        // etseydik ya da boşaltsaydık istemci o satırı EŞLEŞTİREMEZ ve sonsuza dek 'pending'
        // bırakırdı — düzeltmeye çalıştığımız arızanın aynısı. Bu yüzden HAM değer geri döner.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $uuidDegil = $this->customerUpsert();
        $uuidDegil['client_event_id'] = 'olay-42';

        $kimliksiz = $this->customerUpsert();
        unset($kimliksiz['client_event_id']);

        $yanit = $this->pushEvents($token, [$uuidDegil, $kimliksiz]);

        $yanit->assertOk();
        $yanit->assertJsonPath('results.0.status', 'rejected');
        $yanit->assertJsonPath('results.0.reason', 'invalid_client_event_id');
        $yanit->assertJsonPath('results.0.client_event_id', 'olay-42');

        $yanit->assertJsonPath('results.1.status', 'rejected');
        $yanit->assertJsonPath('results.1.reason', 'missing_client_event_id');

        // Kimliği HİÇ olmayan olay ada eşlenemez; `index` bu boşluğun tek kapağıdır (sonuçlar
        // gönderilen olaylarla BİREBİR ve AYNI SIRADADIR).
        $yanit->assertJsonPath('results.0.index', 0);
        $yanit->assertJsonPath('results.1.index', 1);
    }

    #[Test]
    public function reddedilen_olay_idempotency_defterine_yazilmaz(): void
    {
        // 'rejected' KALICI bir karardır ama defterine yazılmaz: aynı kimlikle gelen olay yine
        // reddedilir ('duplicate' DEĞİL). Böylece sunucu kuralı düzelirse (ör. tip geri gelirse)
        // istemci aynı olayı yeniden gönderebilir.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $olay = $this->event('coupon', 'grant', ['id' => (string) Str::uuid7()]);

        $this->pushEvents($token, [$olay])->assertJsonPath('results.0.status', 'rejected');
        $this->pushEvents($token, [$olay])->assertJsonPath('results.0.status', 'rejected');

        $sayi = (int) DB::connection('pgsql_owner')->table('processed_events')->count();
        $this->assertSame(0, $sayi, 'Reddedilen olay idempotency defterine yazılmamalı.');
    }

    #[Test]
    public function zarf_hatalari_hala_422_verir(): void
    {
        // Zarf hatası PROTOKOL hatasıdır: tekrar denemek çözmez ama reddedilecek bir "olay listesi"
        // de yoktur, yani kısmi başarı tanımlanamaz. 422 doğru yanıttır ve öyle KALMALI.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->asToken($token)->postJson('/api/v1/sync/push', [])->assertStatus(422);
        $this->asToken($token)->postJson('/api/v1/sync/push', ['events' => 'dizi-degil'])->assertStatus(422);
        $this->asToken($token)->postJson('/api/v1/sync/push', ['events' => []])->assertStatus(422);

        $tavanUstu = array_fill(0, SyncService::MAX_EVENTS + 1, $this->customerUpsert());
        $this->asToken($token)->postJson('/api/v1/sync/push', ['events' => $tavanUstu])->assertStatus(422);

        $this->assertSame(0, $this->asOwner(fn () => Customer::query()->count()));
    }

    #[Test]
    public function reddetme_gunluge_dusler_ama_kisisel_veri_yazilmaz(): void
    {
        // Reddetme SESSİZ olmamalı (destek arızayı görebilmeli) ama KVKK: günlüğe yalnız
        // client_event_id, entity_type, op ve sebep KODU düşer — ad/telefon/tutar/payload ASLA.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        /** @var list<MessageLogged> $kayitlar */
        $kayitlar = [];
        Log::listen(function (MessageLogged $olay) use (&$kayitlar) {
            $kayitlar[] = $olay;
        });

        $bozuk = $this->event('coupon', 'grant', [
            'id' => (string) Str::uuid7(), 'name' => 'Ayşe Yılmaz',
            'phone_e164' => '+905321112233', 'amount_kurus' => 12345,
        ]);
        $this->pushEvents($token, [$bozuk])->assertOk();

        $olayKaydi = collect($kayitlar)->firstWhere('message', 'sync.event_rejected');
        $this->assertNotNull($olayKaydi, 'Reddedilen olay sunucu günlüğüne düşmeli.');
        $this->assertSame(
            ['client_event_id', 'entity_type', 'op', 'reason'],
            array_keys($olayKaydi->context),
            'Günlük bağlamı bu dört alandan ibaret olmalı (KVKK).'
        );
        $this->assertSame('unknown_entity_type', $olayKaydi->context['reason']);

        $ozet = collect($kayitlar)->firstWhere('message', 'sync.push_rejected');
        $this->assertNotNull($ozet, 'Parti özeti (adet + sebep dağılımı) da günlüğe düşmeli.');
        $this->assertSame(1, $ozet->context['count']);

        $tumMetin = collect($kayitlar)->map(fn (MessageLogged $k) => $k->message.' '.json_encode($k->context))->implode(' ');
        foreach (['Ayşe', '905321112233', '12345'] as $sizinti) {
            $this->assertStringNotContainsString($sizinti, $tumMetin, "Günlüğe kişisel/tutar verisi sızmamalı: {$sizinti}");
        }
    }
}
