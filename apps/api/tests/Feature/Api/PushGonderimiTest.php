<?php

namespace Tests\Feature\Api;

use App\Bildirim\FcmIstemcisi;
use App\Bildirim\PushGondericisi;
use App\Bildirim\PushOlayi;
use App\Models\Device;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * GÖNDERİMİN KENDİSİ — kime gitti, yükte ne vardı, ölü jetona ne oldu.
 *
 * Tetikleme kuralları (hangi olay push doğurur) `PushBildirimiTest`tedir.
 *
 * FCM'e GERÇEK İSTEK ATILMAZ: `Http::fake` hem OAuth2 jeton uç noktasını hem gönderim uç
 * noktasını taklit eder. ⚠️ `Http::fake` İKİNCİ ÇAĞRIDA EZMEZ — ilk stub kazanır; "önce arıza
 * sonra başarı" gibi bir sıra gerekiyorsa `Http::sequence()` şarttır (bu depoda ödenmiş ders).
 */
class PushGonderimiTest extends ApiTestCase
{
    /** FCM'in iki ucu da taklit edilir: önce jeton, sonra gönderim. */
    private function fcmTaklidi(mixed $gonderimYaniti): void
    {
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'jeton', 'expires_in' => 3600]),
            'fcm.googleapis.com/*' => $gonderimYaniti,
        ]);
    }

    /**
     * Hizmet hesabı yapılandırması + İMZASI EZİLMİŞ istemci.
     *
     * ⚠️ İMZA NEDEN EZİLİYOR (ölçüldü): geliştirme makinesi Windows ve orada
     * `openssl_pkey_new` bir `openssl.cnf` bulamayıp "Cannot get key from parameter 1" ile
     * düşüyor — yani test anahtarı ÜRETİLEMİYOR. İmzayı ezmek asıl sınanmak isteneni
     * (yükte kişisel veri yok · kiracı izolasyonu · ölü jeton dalı) test edilebilir kılar.
     * İmza yolunun kendisi `imza_gercekten_uretilir` testinde, openssl varsa doğrulanır.
     */
    private function gonderici(): PushGondericisi
    {
        config([
            'push.fcm.hizmet_hesabi' => base64_encode((string) json_encode([
                'client_email' => 'test@sipario-test.iam.gserviceaccount.com',
                'private_key' => 'TEST-ANAHTARI-IMZA-EZILDI',
                'project_id' => 'sipario-test',
            ])),
        ]);

        return new PushGondericisi(new class extends FcmIstemcisi
        {
            protected function imzaliJwt(array $kimlik): string
            {
                return 'test.jwt.imza';
            }
        });
    }

    private function cihazEkle(string $tenantId, string $userId, ?string $jeton): Device
    {
        return $this->asOwner(fn () => Device::on('pgsql_owner')->create([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $tenantId,
            'user_id' => $userId,
            'platform' => 'android',
            'push_token' => $jeton,
            'last_seen_at' => now(),
        ]));
    }

    #[Test]
    public function yukte_kisisel_veri_yoktur(): void
    {
        /*
         * BRIEF KIRMIZI ÇİZGİ #4'ün push yüzü. Müşteri adı/adresi/tutarı Google'ın
         * sunucularından GEÇMEZ; yalnız olay türü ve bir UUID geçer. Bu test o sınırı yükün
         * TAMAMINI sayarak kilitler — "adı eklemedik" demek yetmez, yükte BAŞKA hiçbir alanın
         * olmadığı da kanıtlanmalı.
         */
        $gonderici = $this->gonderici();
        $this->fcmTaklidi(Http::response(['name' => 'projects/x/messages/1']));

        $a = $this->makeTenant('a');
        $this->cihazEkle($a['tenant']->id, $a['kurye']->id, 'cihaz-jetonu');

        $gonderilen = $gonderici->gonder(
            $a['tenant']->id,
            PushOlayi::SiparisAtandi,
            'siparis-1',
            $a['kurye']->id,
        );

        $this->assertSame(1, $gonderilen);

        Http::assertSent(function ($istek) {
            if (! str_contains($istek->url(), 'fcm.googleapis.com')) {
                return false;
            }

            return $istek->data()['message']['data'] === [
                'olay' => 'siparis_atandi',
                'id' => 'siparis-1',
                'kategori' => 'siparis_atandi',
            ];
        });

        // `notification` alanı GÖNDERİLMEZ: olsaydı bildirimi Android sistemi çizerdi ve
        // sessiz saatler / günlük bütçe / kategori kısma kurallarının hiçbiri işlemezdi.
        // `priority: HIGH` ise Doze modunda dürtünün beklememesi için şart.
        Http::assertSent(function ($istek) {
            if (! str_contains($istek->url(), 'fcm.googleapis.com')) {
                return false;
            }

            return ! array_key_exists('notification', $istek->data()['message'])
                && $istek->data()['message']['android']['priority'] === 'HIGH';
        });
    }

    #[Test]
    public function baska_bayinin_cihazina_asla_gitmez(): void
    {
        // KIRMIZI ÇİZGİ #1. Bu kod KUYRUKTAN koşar; orada RLS'in kiracı değişkeni kurulu
        // DEĞİLDİR ve izolasyon elle (`where tenant_id`) zorlanır. Bir bayinin olayının
        // başka bayinin telefonuna düşmesi, sızıntının en görünür biçimidir.
        $gonderici = $this->gonderici();
        $this->fcmTaklidi(Http::response(['name' => 'ok']));

        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $this->cihazEkle($a['tenant']->id, $a['patron']->id, 'A-jetonu');
        $this->cihazEkle($b['tenant']->id, $b['patron']->id, 'B-jetonu');

        $gonderilen = $gonderici->gonder($a['tenant']->id, PushOlayi::SiparisTeslim, 'sip-1');

        $this->assertSame(1, $gonderilen, 'yalnız A tek bir cihaz almalı');
        Http::assertSent(
            fn ($istek) => ! str_contains($istek->url(), 'fcm.googleapis.com')
                || $istek->data()['message']['token'] === 'A-jetonu'
        );
    }

    #[Test]
    public function olayi_ureten_cihaz_elenir(): void
    {
        $gonderici = $this->gonderici();
        $this->fcmTaklidi(Http::response(['name' => 'ok']));

        $a = $this->makeTenant('a');
        $ureten = $this->cihazEkle($a['tenant']->id, $a['patron']->id, 'ureten-jeton');

        $gonderilen = $gonderici->gonder(
            $a['tenant']->id,
            PushOlayi::SiparisTeslim,
            'sip-1',
            null,
            $ureten->id,
        );

        $this->assertSame(0, $gonderilen, 'kendi dokunuşunun bildirimi gelmemeli');
        Http::assertNotSent(fn ($istek) => str_contains($istek->url(), 'fcm.googleapis.com'));
    }

    #[Test]
    public function olu_jeton_temizlenir_cihaz_kaydi_kalir(): void
    {
        /*
         * Kullanıcı uygulamayı sildiğinde jeton geçersizleşir ve FCM 404/UNREGISTERED döner.
         * Bunu geçici hata sayarsak kuyruk her olayda üç kez yeniden dener; ölü jeton
         * veritabanında sonsuza dek durur ve her siparişte üç boşa HTTP çağrısı üretir.
         *
         * CİHAZ SATIRI SİLİNMEZ: cihaz listesi bayinin güvenlik ekranıdır ("hesabım hangi
         * telefonlarda açık"); bir satırın jetonu öldü diye kaybolması yanlış bilgi verirdi.
         */
        $gonderici = $this->gonderici();
        $this->fcmTaklidi(Http::response([
            'error' => ['status' => 'NOT_FOUND', 'details' => [['errorCode' => 'UNREGISTERED']]],
        ], 404));

        $a = $this->makeTenant('a');
        $cihaz = $this->cihazEkle($a['tenant']->id, $a['patron']->id, 'olu-jeton');

        $gonderilen = $gonderici->gonder($a['tenant']->id, PushOlayi::KasaDevri, 'k1');

        $this->assertSame(0, $gonderilen);

        $taze = $this->asOwner(fn () => Device::on('pgsql_owner')->find($cihaz->id));
        $this->assertNotNull($taze, 'cihaz kaydı SİLİNMEMELİ');
        $this->assertNull($taze->push_token, 'ölü jeton temizlenmeli');
    }

    #[Test]
    public function kurye_yonetici_bildirimi_almaz(): void
    {
        // "Teslim edildi" ve "kasa devri" işi TAKİP EDEN tarafa aittir. Kuryenin kendi
        // teslimini kendisine bildirmek gürültüdür; bayi bir süre sonra hepsini kapatır.
        $gonderici = $this->gonderici();
        $this->fcmTaklidi(Http::response(['name' => 'ok']));

        $a = $this->makeTenant('a');
        $this->cihazEkle($a['tenant']->id, $a['kurye']->id, 'kurye-jetonu');

        $gonderilen = $gonderici->gonder($a['tenant']->id, PushOlayi::SiparisTeslim, 'sip-1');

        $this->assertSame(0, $gonderilen);
    }

    #[Test]
    public function push_yapilandirilmamissa_hicbir_istek_atilmaz(): void
    {
        /*
         * KİMLİK YOKSA SİSTEM KAPALIDIR VE BU BİR HATA DEĞİLDİR: yerel geliştirmede, testte
         * ve Firebase kurulmadan önceki üretimde push sessizce atlanır. Gerekçe mimari —
         * push bu üründe HIZLANDIRICIDIR, taşıyıcı değil; eksik yapılandırma bir iş akışını
         * düşüremez.
         */
        config(['push.fcm.hizmet_hesabi' => null]);
        Http::fake();

        $a = $this->makeTenant('a');
        $this->cihazEkle($a['tenant']->id, $a['patron']->id, 'jeton');

        $gonderilen = (new PushGondericisi(new FcmIstemcisi))
            ->gonder($a['tenant']->id, PushOlayi::KasaDevri, 'k1');

        $this->assertSame(0, $gonderilen);
        Http::assertNothingSent();
    }

    #[Test]
    public function jetonsuz_cihaza_istek_atilmaz(): void
    {
        $gonderici = $this->gonderici();
        $this->fcmTaklidi(Http::response(['name' => 'ok']));

        $a = $this->makeTenant('a');
        $this->cihazEkle($a['tenant']->id, $a['patron']->id, null);

        $gonderilen = $gonderici->gonder($a['tenant']->id, PushOlayi::KasaDevri, 'k1');

        $this->assertSame(0, $gonderilen);
        Http::assertNothingSent();
    }

    #[Test]
    public function imza_gercekten_uretilir(): void
    {
        /*
         * İMZA YOLUNUN KENDİSİ. Diğer testler imzayı ezer (Windows'ta test anahtarı
         * üretilemiyor); bu test onu ezmez ve GERÇEK `openssl_sign` yolunu koşar. Anahtar
         * üretilemiyorsa ATLANIR — çünkü kısıt bizim kodumuzda değil, ortamda.
         *
         * NEDEN ÖNEMLİ: imza hatalıysa FCM "invalid_grant" döner ve hiçbir bildirim gitmez.
         * Bu, tüm push sisteminin tek noktadan sessizce ölebileceği yerdir.
         */
        $anahtar = @openssl_pkey_new([
            'private_key_bits' => 2048,
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
        ]);

        if ($anahtar === false || ! @openssl_pkey_export($anahtar, $pem)) {
            $this->markTestSkipped('Bu ortamda openssl anahtar üretemiyor (Windows/openssl.cnf).');
        }

        config([
            'push.fcm.hizmet_hesabi' => base64_encode((string) json_encode([
                'client_email' => 'test@sipario-test.iam.gserviceaccount.com',
                'private_key' => $pem,
                'project_id' => 'sipario-test',
            ])),
        ]);

        $this->fcmTaklidi(Http::response(['name' => 'ok']));

        $a = $this->makeTenant('a');
        $this->cihazEkle($a['tenant']->id, $a['patron']->id, 'jeton');

        $gonderilen = (new PushGondericisi(new FcmIstemcisi))
            ->gonder($a['tenant']->id, PushOlayi::KasaDevri, 'k1');

        $this->assertSame(1, $gonderilen);

        // JWT üç parçalıdır ve imza parçası BOŞ OLAMAZ.
        Http::assertSent(function ($istek) {
            if (! str_contains($istek->url(), 'oauth2.googleapis.com')) {
                return false;
            }
            $parcalar = explode('.', (string) $istek->data()['assertion']);

            return count($parcalar) === 3 && $parcalar[2] !== '';
        });
    }
}
