<?php

namespace Tests\Feature\Api;

use App\Bildirim\PushOlayi;
use App\Jobs\PushGonderimi;
use App\Models\Device;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * PUSH TETİKLEME KURALLARI — hangi senkron olayı telefonlara dürtü gönderir.
 *
 * Bu dosya kuralın DOĞRU tarafını değil, çoğunlukla YANLIŞ tarafını kilitler: push'ta asıl
 * hasar "gitmesi gereken gitmedi"den çok "gitmemesi gereken gitti"dir. Bayi gereksiz bildirim
 * yağmuru gördüğü an hepsini birden kapatır ve o andan sonra ÖNEMLİ olanı da kaçırır —
 * `GunlukSinir` (mobil taraf) de aynı gerekçeyle vardır.
 *
 * Gönderimin kendisi (HTTP, jeton, ölü jeton temizliği) `PushGonderimiTest`tedir.
 */
class PushBildirimiTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function siparis_kuryeye_atanınca_yalnız_o_kuryeye_is_kuyruga_girer(): void
    {
        Bus::fake();

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $siparis = $this->orderCreated([$this->line()]);
        $siparisId = $siparis['payload']['order']['id'];
        $this->pushEvents($token, [$siparis])->assertOk();

        $cevap = $this->pushEvents($token, [
            $this->orderEvent('assigned', [
                'order_id' => $siparisId,
                'assigned_user_id' => $a['kurye']->id,
            ]),
        ]);

        $cevap->assertOk();
        $this->assertSame('applied', $cevap->json('results.0.status'));

        Bus::assertDispatched(PushGonderimi::class, function (PushGonderimi $is) use ($a, $siparisId) {
            return $is->olay === PushOlayi::SiparisAtandi
                && $is->varlikId === $siparisId
                && $is->aliciUserId === $a['kurye']->id   // yöneticilere DEĞİL, atanan kişiye
                && $is->tenantId === $a['tenant']->id;
        });
    }

    #[Test]
    public function teslim_ve_kasa_devri_yoneticilere_gider(): void
    {
        Bus::fake();

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $siparis = $this->orderCreated([$this->line()]);
        $siparisId = $siparis['payload']['order']['id'];
        $this->pushEvents($token, [$siparis])->assertOk();

        $this->pushEvents($token, [
            $this->orderEvent('delivered', ['order_id' => $siparisId, 'payment_type' => 'nakit']),
            $this->cashHandover(['from_user_id' => $a['kurye']->id]),
        ])->assertOk();

        // `aliciUserId === null` = "bayinin yöneticileri" demektir; alıcı çözümlemesi kuyrukta,
        // `PushGondericisi` içinde yapılır (iş serileştirilirken kullanıcı listesi taşınmaz).
        Bus::assertDispatched(
            PushGonderimi::class,
            fn (PushGonderimi $is) => $is->olay === PushOlayi::SiparisTeslim && $is->aliciUserId === null
        );
        Bus::assertDispatched(
            PushGonderimi::class,
            fn (PushGonderimi $is) => $is->olay === PushOlayi::KasaDevri && $is->aliciUserId === null
        );
    }

    #[Test]
    public function olayi_ureten_cihaz_kendi_bildirimini_almaz(): void
    {
        Bus::fake();

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $cihazId = (string) Str::uuid7();

        $siparis = $this->orderCreated([$this->line()], [], ['device_id' => $cihazId]);
        $siparisId = $siparis['payload']['order']['id'];
        $this->pushEvents($token, [$siparis])->assertOk();

        $this->pushEvents($token, [
            $this->orderEvent(
                'assigned',
                ['order_id' => $siparisId, 'assigned_user_id' => $a['kurye']->id],
                ['device_id' => $cihazId]
            ),
        ])->assertOk();

        // Cihaz kimliği işe TAŞINIR; eleme kuyrukta yapılır. Taşınmazsa patron kendi
        // dokunuşunun bildirimini kendi telefonunda görürdü.
        Bus::assertDispatched(
            PushGonderimi::class,
            fn (PushGonderimi $is) => $is->haricCihazId === $cihazId
        );
    }

    #[Test]
    public function ayni_olay_ikinci_kez_gelirse_bildirim_tekrarlanmaz(): void
    {
        // Offline istemcinin yeniden denemesi NORMALDİR (`duplicate`). Bunu atlamasaydık ağı
        // zayıf bir kuryenin her denemesi patronun telefonunu yeniden öttürürdü.
        Bus::fake();

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $siparis = $this->orderCreated([$this->line()]);
        $siparisId = $siparis['payload']['order']['id'];
        $this->pushEvents($token, [$siparis])->assertOk();

        $atama = $this->orderEvent('assigned', [
            'order_id' => $siparisId,
            'assigned_user_id' => $a['kurye']->id,
        ]);

        $this->pushEvents($token, [$atama])->assertOk();
        $ikinci = $this->pushEvents($token, [$atama]);

        $this->assertSame('duplicate', $ikinci->json('results.0.status'));
        Bus::assertDispatchedTimes(PushGonderimi::class, 1);
    }

    #[Test]
    public function ara_tahsilat_iptali_kasa_devri_bildirimi_dogurmaz(): void
    {
        // `reverses_handover_id` dolu satır bir devir DEĞİL, bir devrin iptalidir. "Kurye kasayı
        // devretti" bildirimi göndermek gerçeğin tersini söylerdi.
        Bus::fake();

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $devir = $this->cashHandover([
            'from_user_id' => $a['kurye']->id,
            'counted_cash_kurus' => 4000,
        ]);
        $this->pushEvents($token, [$devir])->assertOk();
        Bus::assertDispatchedTimes(PushGonderimi::class, 1);

        $this->pushEvents($token, [
            $this->cashHandover([
                'from_user_id' => $a['kurye']->id,
                'counted_cash_kurus' => -4000,
                'reverses_handover_id' => $devir['payload']['id'],
            ]),
        ])->assertOk();

        // Sayı ARTMAMALI: ikinci olay uygulandı ama push doğurmadı.
        Bus::assertDispatchedTimes(PushGonderimi::class, 1);
    }

    #[Test]
    public function reddedilen_olay_bildirim_dogurmaz(): void
    {
        // KIRMIZI ÇİZGİ #1'in bildirim yüzü: başka bayinin kullanıcısına atama reddedilir
        // (`domain_rejected`). Uygulanmamış bir olayın bildirimi, olmamış bir işi haber verirdi.
        Bus::fake();

        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $token = $this->tokenFor($a['patron']);

        $siparis = $this->orderCreated([$this->line()]);
        $siparisId = $siparis['payload']['order']['id'];
        $this->pushEvents($token, [$siparis])->assertOk();

        $cevap = $this->pushEvents($token, [
            $this->orderEvent('assigned', [
                'order_id' => $siparisId,
                'assigned_user_id' => $b['kurye']->id,
            ]),
        ]);

        $this->assertSame('rejected', $cevap->json('results.0.status'));
        $this->assertSame('domain_rejected', $cevap->json('results.0.reason'));
        Bus::assertNotDispatched(PushGonderimi::class);
    }

    #[Test]
    public function cihaz_kaydi_push_jetonunu_sessizce_silmez(): void
    {
        /*
         * SESSİZ ARIZA KAPISI. FCM jetonu uygulama açılışında ASENKRON gelir; cihaz kaydı
         * ondan önce koşar. "Alan gönderilmedi"yi "alanı boşalt" saysaydık her açılış jetonu
         * silerdi — hata çıkmaz, yalnız bildirimler bir gün gelmemeye başlardı.
         */
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $cihazId = (string) Str::uuid7();

        $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => $cihazId,
            'platform' => 'android',
            'push_token' => 'jeton-abc',
        ])->assertCreated();

        // İkinci kayıt push_token TAŞIMIYOR (tipik açılış sırası).
        $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => $cihazId,
            'platform' => 'android',
            'app_version' => '0.22.0',
        ])->assertOk();

        $cihaz = $this->asOwner(fn () => Device::query()->find($cihazId));
        $this->assertSame('jeton-abc', $cihaz->push_token,
            'gönderilmeyen alan DOKUNULMAMIŞ olmalı — silinirse push sessizce ölür');

        // AÇIKÇA null gönderilirse SİLİNİR: bu "dokunma" değil, "boşalt"tır (çıkışta kullanılır).
        $this->asToken($token)->postJson('/api/v1/devices', [
            'device_id' => $cihazId,
            'platform' => 'android',
            'push_token' => null,
        ])->assertOk();

        $cihaz = $this->asOwner(fn () => Device::query()->find($cihazId));
        $this->assertNull($cihaz->push_token);
    }
}
