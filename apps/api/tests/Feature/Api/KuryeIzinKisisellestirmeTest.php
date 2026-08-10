<?php

namespace Tests\Feature\Api;

use App\Models\TenantSetting;
use App\Models\User;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * KİŞİYE ÖZEL KURYE YETKİSİ — 3 durumlu DEVRALMA (kullanıcı kararı 2026-08-10, migration 004008).
 *
 * Yetkiler bugüne kadar YALNIZ `tenant_settings` üzerindeydi ve bayideki tüm kuryeler için ortaktı.
 * Artık aynı 13 anahtar `users` üzerinde NULLABLE'dır: NULL = "bayi varsayılanını devral",
 * true/false = kişiye özel ezme. Etkin yetki = `users.courier_x ?? tenant_settings.courier_x` ve bu
 * birleştirmeyi İSTEMCİ yapar — sunucu iki katmanı AYRI yayınlar (`team` + `tenant_settings`).
 *
 * Bu dosya dört şeyi kilitler ve dördü de ayrı arıza sınıfıdır:
 *  1. ÜÇ DEĞERİN ÜÇÜ DE İFADE EDİLEBİLİR: anahtar yok (koru) ≠ açık null (devral) ≠ bool (ezme).
 *     Ortadaki ayrım kaybolursa ya eski istemci patronun az önce verdiği yetkiyi siler, ya da
 *     "varsayılana dön" düğmesi hiç çalışmaz.
 *  2. `"false"` METNİ FALSE'TUR: PHP'nin gevşek dönüşümü onu true sayar ve KAPALI gönderilen bir
 *     yetki AÇIK yazılırdı (tenant_settings tarafında ödenmiş ders).
 *  3. YETKİ YÜKSELTME KAPISI: kurye kendi cihazından kendi satırına yetki yazamaz — ama adını/
 *     telefonunu yazabilmeye devam eder (kapı yalnız yetki alanlarına tabidir).
 *  4. ALAN TELEFONA ULAŞIR: `users` senkron delta günlüğünde YOKTUR; yetkilerin inmesinin tek
 *     kanalı `team` bloğudur ("sunucuda doğru duran ama inmeyen alan YOKTUR", migration 802).
 */
class KuryeIzinKisisellestirmeTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function kisiye_ozel_yetki_yazilir_ve_team_blogunda_doner(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $yanit = $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id,
            'name' => 'A Kurye',
            'courier_can_discount' => true,   // bayi varsayılanı false — kişiye özel AÇILIYOR
            'courier_can_orders' => false,    // bayi varsayılanı true — kişiye özel KAPATILIYOR
        ])]);
        $yanit->assertJsonPath('results.0.status', 'applied');

        /** @var User $taze */
        $taze = $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id));
        $this->assertTrue($taze->courier_can_discount);
        $this->assertFalse($taze->courier_can_orders);
        $this->assertNull($taze->courier_can_collect, 'Gönderilmeyen anahtar devralmada kalmalı.');

        // Yayın kanalı: push yanıtının `team` bloğu. Buradan inmezse kuryenin telefonu yetkiyi
        // ASLA öğrenemez (users delta günlüğünde yer almaz).
        $kurye = collect($yanit->json('team'))->firstWhere('id', $a['kurye']->id);
        $this->assertNotNull($kurye, 'Kurye team bloğunda olmalı.');
        $this->assertTrue($kurye['courier_can_discount']);
        $this->assertFalse($kurye['courier_can_orders']);
        $this->assertNull($kurye['courier_can_collect']);

        // Pull da aynı bloğu yayınlar (snapshot ve delta yollarının ikisi de).
        $snapshot = $this->pullSince($token, 0)->assertOk();
        $snapKurye = collect($snapshot->json('team'))->firstWhere('id', $a['kurye']->id);
        $this->assertTrue($snapKurye['courier_can_discount']);
        $this->assertFalse($snapKurye['courier_can_orders']);
    }

    /**
     * DEVRALMA HÂLİ: dokunulmamış bir kurye 13 anahtarın hepsinde null yayınlanır ve bayi
     * varsayılanları AYRI kanaldan (`tenant_settings`) iner. İkisi birleşseydi istemci
     * "devralıyor" ile "kişiye özel açık"ı bir daha ayıramazdı.
     */
    #[Test]
    public function dokunulmamis_kurye_tum_yetkilerde_devralir_ve_iki_katman_ayri_yayinlanir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // Bayi varsayılan satırını kur (yeni bayide tenant_settings henüz yoktur).
        $this->pushEvents($token, [$this->tenantSettingsUpsert(['courier_can_discount' => true])])
            ->assertJsonPath('results.0.status', 'applied');

        $snapshot = $this->pullSince($token, 0)->assertOk();

        $kurye = collect($snapshot->json('team'))->firstWhere('id', $a['kurye']->id);
        foreach (array_keys(TenantSetting::KURYE_IZINLERI) as $kolon) {
            $this->assertArrayHasKey($kolon, $kurye, "team bloğu {$kolon} taşımıyor.");
            $this->assertNull($kurye[$kolon], "Dokunulmamış kurye {$kolon} için devralmalı (null).");
        }

        // Bayi katmanı kendi kanalından iner ve kişisel katmandan BAĞIMSIZDIR.
        $ayarlar = $snapshot->json('entities.tenant_settings.0');
        $this->assertTrue($ayarlar['courier_can_discount'], 'Bayi varsayılanı yayında kalmalı.');
    }

    /**
     * SÜRÜM ÇARPIKLIĞI (`SurumCarpikligiTest::eski_istemci_kullanicinin_telefonunu_silmez` ile
     * aynı sınıf): yetki alanlarını BİLMEYEN eski bir build, kuryenin adını düzeltmek için profil
     * yazdığında patronun az önce verdiği kişisel yetkiyi silmemelidir.
     */
    #[Test]
    public function anahtar_hic_gonderilmeyince_kisisel_deger_korunur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'courier_can_discount' => true, 'courier_can_expense' => false,
        ], ['occurred_at' => now()->subMinute()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        // ESKİ build: yetki anahtarlarını hiç göndermiyor, yalnız adı düzeltiyor.
        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'name' => 'Mehmet K.',
        ])])->assertJsonPath('results.0.status', 'applied');

        /** @var User $taze */
        $taze = $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id));
        $this->assertSame('Mehmet K.', $taze->name);
        $this->assertTrue($taze->courier_can_discount, 'Eski istemci kişisel yetkiyi sildi.');
        $this->assertFalse($taze->courier_can_expense, 'Kişisel KAPALI ezme de korunmalı.');
    }

    /**
     * "VARSAYILANA DÖN" düğmesi: AÇIKÇA null göndermek kişisel ezmeyi kaldırır. Anahtarın YOKLUĞU
     * ile değerin null OLMASI ayrı şeyler olmasaydı bu niyet hiç ifade edilemezdi.
     */
    #[Test]
    public function acik_null_kisisel_ezmeyi_kaldirir_ve_devralmaya_dondurur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'courier_can_day_end' => true,
        ], ['occurred_at' => now()->subMinute()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertTrue($this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id)->courier_can_day_end));

        $yanit = $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'courier_can_day_end' => null,
        ])]);
        $yanit->assertJsonPath('results.0.status', 'applied');

        $this->assertNull(
            $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id)->courier_can_day_end),
            'Açık null kolonu NULL yapmalı (= bayi varsayılanını devral).'
        );
        $this->assertNull(
            collect($yanit->json('team'))->firstWhere('id', $a['kurye']->id)['courier_can_day_end'],
            'Devralmaya dönüş team bloğunda da null görünmeli.'
        );
    }

    /**
     * `"false"` METNİ FALSE'TUR. PHP'nin gevşek dönüşümü boş olmayan her metni true sayar; bu
     * kapı olmasaydı "kapalı" diye gönderilen bir yetki AÇIK yazılırdı — sessiz yetki yükseltme.
     */
    #[Test]
    public function false_metni_yetkiyi_acmaz(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id,
            'courier_can_collect' => 'false',
            'courier_can_customers' => '0',
            'courier_can_orders' => 'true',
            'courier_can_view_history' => 1,
        ])])->assertJsonPath('results.0.status', 'applied');

        /** @var User $taze */
        $taze = $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id));
        $this->assertFalse($taze->courier_can_collect, '"false" metni true yazıldı — yetki sessizce açıldı.');
        $this->assertFalse($taze->courier_can_customers);
        $this->assertTrue($taze->courier_can_orders);
        $this->assertTrue($taze->courier_can_view_history);
    }

    /**
     * OKUNAMAYAN DEĞER DEVRALMAYA DÜŞER, uydurulmuş bir ezmeye değil: yetki alanında "belirsiz"
     * diye bir durum olamaz ve güvenli taraf bayinin kendi varsayılanıdır.
     */
    #[Test]
    public function okunamayan_deger_devralmaya_duser(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'courier_can_discount' => true,
        ], ['occurred_at' => now()->subMinute()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'courier_can_discount' => 'belki',
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->assertNull(
            $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id)->courier_can_discount),
            'Çözülemeyen değer kişisel ezme olarak yazılmamalı.'
        );
    }

    /**
     * YETKİ YÜKSELTME KAPISI. Kurye kendi cihazından kendi satırına `courier_can_discount: true`
     * yazabilseydi bayinin kapattığı iskontoyu offline kuyruktan açardı ve patron hiçbir şey
     * görmezdi. Kapı YALNIZ yetki alanlarına tabidir: aynı kuryenin ad/telefon yazımı uygulanır.
     */
    #[Test]
    public function kurye_aktorun_yetki_yazimi_reddedilir_ad_telefon_yazimi_uygulanir(): void
    {
        $a = $this->makeTenant('a');
        $kuryeToken = $this->tokenFor($a['kurye']);

        $red = $this->pushEvents($kuryeToken, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'name' => 'A Kurye', 'courier_can_discount' => true,
        ])]);
        $red->assertJsonPath('results.0.status', 'rejected');
        $red->assertJsonPath('results.0.reason', 'domain_rejected');

        /** @var User $sonra */
        $sonra = $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id));
        $this->assertNull($sonra->courier_can_discount, 'Reddedilen olay hiçbir kolona dokunmamalı.');

        // Aynı kullanıcı, aynı yolla: ad + telefon yazımı ESKİSİ GİBİ uygulanır.
        $this->pushEvents($kuryeToken, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'name' => 'Mehmet Kurye', 'phone' => '+905321112233',
        ])])->assertJsonPath('results.0.status', 'applied');

        /** @var User $taze */
        $taze = $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id));
        $this->assertSame('Mehmet Kurye', $taze->name);
        $this->assertSame('+905321112233', $taze->phone);
    }

    /**
     * Kapı KENDİ SATIRINA ÖZEL DEĞİL: kurye bir BAŞKA kuryenin yetkisini de yazamaz. (Aksi hâlde
     * iki kurye birbirinin yetkisini açardı — aynı yükseltme, bir dolaylı adımla.)
     */
    #[Test]
    public function kurye_baskasinin_yetkisini_de_yazamaz(): void
    {
        $a = $this->makeTenant('a');
        $kuryeToken = $this->tokenFor($a['kurye']);

        $this->pushEvents($kuryeToken, [$this->userProfileUpsert([
            'id' => $a['operator']->id, 'courier_can_expense' => true,
        ])])->assertJsonPath('results.0.status', 'rejected');

        $this->assertNull($this->asOwner(fn () => User::query()->findOrFail($a['operator']->id)->courier_can_expense));
    }

    /** Operatör bayinin günlük işini çevirir ve Ekip ekranı ona açıktır — yetki yazabilmeli. */
    #[Test]
    public function operator_kurye_yetkisi_atayabilir(): void
    {
        $a = $this->makeTenant('a');

        $this->pushEvents($this->tokenFor($a['operator']), [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'courier_can_expense' => true,
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->assertTrue($this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id)->courier_can_expense));
    }

    /**
     * LWW BOZULMADI: yetki alanları eklendi diye çakışma çözümü değişmez. Eski damgalı olay
     * 'stale' döner ve TEK BİR kolona bile dokunmaz.
     */
    #[Test]
    public function eski_damgali_olay_stale_kalir_ve_yetkiyi_ezmez(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'name' => 'Yeni Ad', 'courier_can_discount' => true,
        ], ['occurred_at' => now()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        // Geç gelen ESKİ yazım (çevrimdışı kalmış ikinci cihaz).
        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'name' => 'Eski Ad', 'courier_can_discount' => false,
        ], ['occurred_at' => now()->subHour()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'stale');

        /** @var User $taze */
        $taze = $this->asOwner(fn () => User::query()->findOrFail($a['kurye']->id));
        $this->assertSame('Yeni Ad', $taze->name);
        $this->assertTrue($taze->courier_can_discount, 'Stale olay kişisel yetkiyi ezdi.');
    }

    /**
     * TEK DOĞRU YER BEKÇİSİ: kişisel yetki kolonlarının listesi `TenantSetting::KURYE_IZINLERI`'nden
     * TÜRETİLİR. İki taraf ıraksarsa arıza SESSİZDİR — eksik kalan kolon ne yazılır ne yayınlanır,
     * hiçbir yerde hata da vermez. Bu yüzden bağ yazıyla değil makineyle tutulur.
     */
    #[Test]
    public function yetki_kolon_listesi_tenant_settings_ile_birebir_aynidir(): void
    {
        $this->assertSame(
            array_keys(TenantSetting::KURYE_IZINLERI),
            User::kuryeIzinKolonlari(),
            'Kişisel yetki listesi bayi varsayılan listesinden ıraksadı.'
        );
        $this->assertCount(13, User::kuryeIzinKolonlari());
    }
}
