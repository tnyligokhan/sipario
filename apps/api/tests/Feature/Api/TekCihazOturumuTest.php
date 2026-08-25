<?php

namespace Tests\Feature\Api;

use App\Models\Device;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * TEK HESAP = TEK CİHAZ (kullanıcı kararı 2026-08-22).
 *
 * Bir hesap yeni bir telefonda açıldığında o hesabın diğer bütün oturumları kapanır. Bu dosya
 * dört şeyi birden kilitler: (1) eski token gerçekten geçersiz, (2) kullanıcı NEDEN çıktığını
 * öğrenebiliyor, (3) düşen telefon bayinin bildirimlerini almaya devam etmiyor, (4) kapsam
 * KULLANICIDIR — bayideki diğer hesaplar ayakta kalır.
 */
class TekCihazOturumuTest extends ApiTestCase
{
    /**
     * @param  array<string, mixed>  $govde
     * @return array<string, mixed>
     */
    private function girisGovdesiCihazli(array $govde, string $cihazId, ?string $pushToken = null): array
    {
        $device = ['device_id' => $cihazId, 'platform' => 'android'];
        if ($pushToken !== null) {
            $device['push_token'] = $pushToken;
        }

        return $govde + ['device' => $device];
    }

    #[Test]
    public function yeni_cihazda_giris_eski_cihazin_oturumunu_kapatir(): void
    {
        $a = $this->makeTenant('a');
        $govde = $this->girisGovdesi($a['tenant'], $a['patron']);

        $eskiToken = $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesiCihazli($govde, (string) Str::uuid7())
        )->json('token');

        // Eski telefon şu an ÇALIŞIYOR — testin anlamlı olmasının şartı.
        $this->asToken($eskiToken)->getJson('/api/v1/auth/me')->assertOk();

        $yeniToken = $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesiCihazli($govde, (string) Str::uuid7())
        )->json('token');

        // Eski telefon kapı dışarı — ve NEDENİNİ öğreniyor. `code` sözleşmenin parçasıdır:
        // mobil istemci metne değil ona bakar (metin değişince istemci kırılmasın).
        $this->asToken($eskiToken)
            ->getJson('/api/v1/auth/me')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'oturum_baska_cihazda');

        // Yeni telefon çalışıyor.
        $this->asToken($yeniToken)->getJson('/api/v1/auth/me')->assertOk();
    }

    #[Test]
    public function dusen_tokenin_suresi_de_gecmise_cekilir(): void
    {
        // ⚠️ ASIL KAPIYI SANCTUM TUTAR, açıklama katmanı değil. `RejectRevokedToken` yarın bir
        // rota grubunda takılmayı unutulursa düşürülmüş token YİNE de işe yaramamalı — Sanctum'un
        // kendi süre kontrolü (`Guard::isValidAccessToken`) onu reddeder. Bu test o ikinci kemeri
        // ölçer; middleware'in varlığına bakmaz.
        $a = $this->makeTenant('a');
        $govde = $this->girisGovdesi($a['tenant'], $a['patron']);

        $this->postJson('/api/v1/auth/login', $this->girisGovdesiCihazli($govde, (string) Str::uuid7()));
        $this->postJson('/api/v1/auth/login', $this->girisGovdesiCihazli($govde, (string) Str::uuid7()));

        $dusen = DB::connection('pgsql_owner')
            ->table('personal_access_tokens')
            ->whereNotNull('revoked_at')
            ->first();

        $this->assertNotNull($dusen, 'eski token satırı SİLİNMEMELİ — sebebi taşıyan tek yer o');
        $this->assertSame('baska_cihaz', $dusen->revoked_reason);
        $this->assertNotNull($dusen->expires_at);
        $this->assertTrue(
            Carbon::parse($dusen->expires_at)->isPast(),
            'expires_at geçmişe çekilmezse kapıyı yalnız middleware tutar'
        );
    }

    #[Test]
    public function dusen_cihazin_push_jetonu_temizlenir(): void
    {
        // Oturumu kapanan telefon bayinin bildirimlerini almaya DEVAM ETMEMELİ: bildirim gövdesi
        // müşteri adı, adres ve veresiye tutarı taşıyabilir (KVKK, kırmızı çizgi #4).
        $a = $this->makeTenant('a');
        $govde = $this->girisGovdesi($a['tenant'], $a['patron']);
        $eskiCihaz = (string) Str::uuid7();
        $yeniCihaz = (string) Str::uuid7();

        $this->postJson('/api/v1/auth/login', $this->girisGovdesiCihazli($govde, $eskiCihaz, 'fcm-eski'));
        $this->postJson('/api/v1/auth/login', $this->girisGovdesiCihazli($govde, $yeniCihaz, 'fcm-yeni'));

        $cihazlar = $this->asOwner(
            fn () => Device::query()->whereIn('id', [$eskiCihaz, $yeniCihaz])->pluck('push_token', 'id')
        );

        $this->assertNull($cihazlar[$eskiCihaz]);
        $this->assertSame('fcm-yeni', $cihazlar[$yeniCihaz], 'yeni cihazın jetonu duruyor');
    }

    #[Test]
    public function ayni_cihazdan_yeniden_giris_kendi_push_jetonunu_silmez(): void
    {
        // EN KOLAY KAÇIRILAN YER: aynı telefondan çıkıp yeniden girmek de eski bir token bırakır.
        // Düşen token'ın cihazı bu girişin cihazından ELENMESEYDİ, her yeniden giriş kullanıcının
        // AZ ÖNCE kaydettiği push jetonunu siler ve bildirimler sessizce kesilirdi.
        $a = $this->makeTenant('a');
        $govde = $this->girisGovdesi($a['tenant'], $a['patron']);
        $cihaz = (string) Str::uuid7();

        $this->postJson('/api/v1/auth/login', $this->girisGovdesiCihazli($govde, $cihaz, 'fcm-1'));
        $yeniToken = $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesiCihazli($govde, $cihaz, 'fcm-2')
        )->json('token');

        $cihazKaydi = $this->asOwner(fn () => Device::query()->find($cihaz));
        $this->assertSame('fcm-2', $cihazKaydi->push_token);

        $this->asToken($yeniToken)->getJson('/api/v1/auth/me')->assertOk();
    }

    #[Test]
    public function ayni_bayideki_diger_hesaplarin_oturumu_dusmez(): void
    {
        // KAPSAM KULLANICIDIR, BAYİ DEĞİL. Patron, operatör ve kurye AYRI hesaplardır; patronun
        // girişi kuryenin telefonunu düşürseydi tek kişilik olmayan her bayide iki kişi sırayla
        // birbirini atardı.
        $a = $this->makeTenant('a');

        $kuryeToken = $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesiCihazli($this->girisGovdesi($a['tenant'], $a['kurye']), (string) Str::uuid7())
        )->json('token');

        $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesiCihazli($this->girisGovdesi($a['tenant'], $a['patron']), (string) Str::uuid7())
        )->assertOk();

        $this->asToken($kuryeToken)
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('user.id', $a['kurye']->id);
    }

    #[Test]
    public function baska_bayinin_ayni_kullanici_adli_hesabi_etkilenmez(): void
    {
        // Kullanıcı adı bayi İÇİNDE tekildir: iki bayide de "patron" vardır. Düşürme sorgusu
        // kullanıcı adına değil `users` satırına bağlı olmalı.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $bToken = $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesiCihazli($this->girisGovdesi($b['tenant'], $b['patron']), (string) Str::uuid7())
        )->json('token');

        $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesiCihazli($this->girisGovdesi($a['tenant'], $a['patron']), (string) Str::uuid7())
        )->assertOk();

        $this->asToken($bToken)
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('tenant.id', $b['tenant']->id);
    }

    #[Test]
    public function cihaz_blogu_olmadan_giris_de_eski_oturumu_dusurur(): void
    {
        // `device` bloğu OPSİYONELDİR (curl, test aracı, ileride web istemcisi). Düşürme cihaz
        // kimliğine bağlanmamalı: bağlansaydı bloğu göndermeyen bir istemci kuralın dışında kalırdı.
        $a = $this->makeTenant('a');
        $govde = $this->girisGovdesi($a['tenant'], $a['patron']);

        $eskiToken = $this->postJson('/api/v1/auth/login', $govde)->json('token');
        $this->postJson('/api/v1/auth/login', $govde)->assertOk();

        $this->asToken($eskiToken)
            ->getJson('/api/v1/auth/me')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'oturum_baska_cihazda');
    }

    #[Test]
    public function cikis_yapilmis_tokende_sebep_kodu_bulunmaz(): void
    {
        // Kendi isteğiyle çıkan kullanıcıya "başka bir cihazda açıldı" demek YALAN olurdu.
        // `logout` satırı siler; silinen satırın sebebi de olmaz ve yanıt çıplak 401'dir.
        $a = $this->makeTenant('a');

        $token = $this->postJson(
            '/api/v1/auth/login',
            $this->girisGovdesi($a['tenant'], $a['patron'])
        )->json('token');

        $this->asToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();

        $this->asToken($token)
            ->getJson('/api/v1/auth/me')
            ->assertUnauthorized()
            ->assertJsonMissingPath('code');
    }
}
