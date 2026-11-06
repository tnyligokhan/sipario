<?php

namespace Tests\Feature\Api;

use App\Bildirim\FcmIstemcisi;
use App\Bildirim\PushGondericisi;
use App\Bildirim\PushOlayi;
use App\Bildirim\SurumDuyurucu;
use App\Jobs\YeniSurumGonderimi;
use App\Models\Device;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * YENİ SÜRÜM DUYURUSU — uygulama kapalıyken de haber gitsin (kullanıcı isteği 2026-11-06).
 *
 * Kuyruk taklit edilir: burada sorulan "ne zaman duyurulur", gönderimin kendisi aşağıda ayrı sınanır.
 */
class SurumDuyurusuTest extends ApiTestCase
{
    private const ANAHTAR = 'surum_duyurusu:saha';

    protected function setUp(): void
    {
        parent::setUp();
        Cache::forget(self::ANAHTAR);
        config(['push.surum.kanal' => 'saha']);
    }

    private function yayin(int $yapim, string $surum = '1.17.0'): void
    {
        Http::fake(['github.com/*' => Http::response(['yapim' => $yapim, 'surum' => $surum])]);
    }

    #[Test]
    public function ilk_kosu_yalniz_kaydeder_kimseye_gondermez(): void
    {
        Queue::fake();
        $this->yayin(630);

        $this->assertNull((new SurumDuyurucu)->denetle());

        Queue::assertNothingPushed();
        $this->assertSame(630, Cache::get(self::ANAHTAR));
    }

    #[Test]
    public function daha_buyuk_yapim_bir_kez_duyurulur(): void
    {
        Queue::fake();
        Cache::forever(self::ANAHTAR, 629);
        $this->yayin(630);

        $this->assertSame(630, (new SurumDuyurucu)->denetle());
        $this->assertNull((new SurumDuyurucu)->denetle());

        Queue::assertPushed(YeniSurumGonderimi::class, 1);
        Queue::assertPushed(
            YeniSurumGonderimi::class,
            fn (YeniSurumGonderimi $is) => $is->yapim === 630 && $is->surum === '1.17.0',
        );
    }

    #[Test]
    public function yayin_geri_alinirsa_duyurulmaz_ve_kayit_gerilemez(): void
    {
        Queue::fake();
        Cache::forever(self::ANAHTAR, 630);
        $this->yayin(629);

        $this->assertNull((new SurumDuyurucu)->denetle());

        Queue::assertNothingPushed();
        $this->assertSame(630, Cache::get(self::ANAHTAR));
    }

    #[Test]
    public function okunamayan_surum_dosyasi_sessizce_atlanir(): void
    {
        Queue::fake();
        Cache::forever(self::ANAHTAR, 629);
        Http::fake(['github.com/*' => Http::response('bulunamadı', 404)]);

        $this->assertNull((new SurumDuyurucu)->denetle());

        Queue::assertNothingPushed();
        $this->assertSame(629, Cache::get(self::ANAHTAR));
    }

    #[Test]
    public function baglanti_kopuklugu_komutu_dusurmez(): void
    {
        Queue::fake();
        Cache::forever(self::ANAHTAR, 629);
        Http::fake(fn () => throw new ConnectionException('ağ yok'));

        $this->artisan('surum:duyur')->assertSuccessful();

        Queue::assertNothingPushed();
    }

    #[Test]
    public function adres_kanali_tasir_ve_her_istekte_onbellegi_atlar(): void
    {
        Queue::fake();
        $this->yayin(630);

        (new SurumDuyurucu)->denetle();

        Http::assertSent(fn ($istek) => str_contains($istek->url(), '/releases/download/saha/surum.json?t='));
    }

    #[Test]
    public function zamanlayiciya_bagli(): void
    {
        $this->artisan('schedule:list')->expectsOutputToContain('surum:duyur');
    }

    #[Test]
    public function durtu_her_bayinin_cihazina_gider_ve_yukte_kisisel_veri_yoktur(): void
    {
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'jeton', 'expires_in' => 3600]),
            'fcm.googleapis.com/*' => Http::response(['name' => 'x']),
        ]);
        config([
            'push.fcm.hizmet_hesabi' => base64_encode((string) json_encode([
                'client_email' => 'test@sipario-test.iam.gserviceaccount.com',
                'private_key' => 'TEST-ANAHTARI-IMZA-EZILDI',
                'project_id' => 'sipario-test',
            ])),
        ]);
        $gonderici = new PushGondericisi(new class extends FcmIstemcisi
        {
            protected function imzaliJwt(array $kimlik): string
            {
                return 'test.jwt.imza';
            }
        });

        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $this->cihaz($a['tenant']->id, $a['kurye']->id, 'jeton-1');
        $this->cihaz($b['tenant']->id, $b['patron']->id, 'jeton-2');
        $this->cihaz($b['tenant']->id, $b['operator']->id, null);

        $adet = $gonderici->herkese(PushOlayi::YeniSurum, '630', ['surum' => '1.17.0']);

        $this->assertSame(2, $adet);
        Http::assertSent(function ($istek) {
            if (! str_contains($istek->url(), 'fcm.googleapis.com')) {
                return false;
            }

            return $istek['message']['data'] === [
                'olay' => 'yeni_surum',
                'id' => '630',
                'kategori' => 'guncelleme_var',
                'surum' => '1.17.0',
            ];
        });
    }

    private function cihaz(string $tenantId, string $userId, ?string $jeton): Device
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
}
