<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\CustomerPhone;
use App\Models\Product;
use App\Models\TenantSetting;
use App\Models\User;
use App\Support\Sync\SyncService;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * SÜRÜM ÇARPIKLIĞI SÖZLEŞMESİ — "sunucu şeması/kodu ilerledi, telefondaki uygulama ESKİ kaldı".
 *
 * Mağazadan güncelleme almak bayinin elindedir; sunucu migration'ı bizim. İkisi arasındaki boşluk
 * GÜNLER sürer ve o boşlukta eski istemci hâlâ yazar. Bu dosya o boşlukta veri kaybolmadığını
 * kanıtlar — kırmızı çizgi #3 ("hiçbir kayıt kaybolmaz") yalnız ağ/kilit hâlleri için değil,
 * ŞEMA EVRİMİ için de geçerlidir.
 *
 * TEMEL KURAL (bu dosyanın konusu): **anahtar YOK ≠ anahtar null.**
 *  - Payload'da HİÇ OLMAYAN kolon = "bu sürüm o alanı bilmiyor" → sunucudaki değer KORUNUR.
 *  - Payload'da AÇIKÇA null gelen kolon = "temizle" → yazılır.
 * Bu ayrım olmadan LWW'nin "satırın tamamını yaz" doğası, migration'la eklenen her yeni kolonu
 * eski istemcinin ilk yazımında SESSİZCE SİLER: taze occurred_at LWW'yi kazanır, kimse hata
 * görmez, alan boşalır.
 */
class SurumCarpikligiTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /**
     * v12 istemcisinin (2026-08-04 öncesi build) BİLDİĞİ tenant_settings alanları. `iban`,
     * beş kurye yetkisi ve `order_code_display` bu listede YOKTUR — çünkü o sürüm derlendiğinde
     * kolonlar henüz doğmamıştı. Sahadaki gerçek payload budur.
     *
     * @return array<string, mixed>
     */
    private function eskiIstemciAyarPayloadu(string $isim = 'Eski Build Su Bayii'): array
    {
        return [
            'business_name' => $isim,
            'owner_name' => 'Ali Usta',
            'phone' => '+902421112233',
            'whatsapp' => null,
            'address_text' => 'Kepez',
            'tax_office' => null,
            'tax_number' => null,
            'opens_at' => '08:30',
            'closes_at' => '20:00',
            'receipt_note' => null,
        ];
    }

    // ----------------------------------------------------------------------------------
    // A) tenant_settings — yeni kolonlar eski istemcinin yazımında hayatta kalmalı
    // ----------------------------------------------------------------------------------

    #[Test]
    public function eski_istemci_bilmedigi_iban_ve_kurye_yetkilerini_silmez(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // 1) GÜNCEL bir yüzey (yeni telefon ya da panel) tam satırı yazar.
        $this->pushEvents($token, [$this->tenantSettingsUpsert([
            'business_name' => 'Aspendos Su',
            'iban' => 'TR330006100519786457841326',
            'iban_owner_name' => 'Mehmet Yılmaz',
            'reminder_template' => 'Sayın *musteriadi*, *siparistutar* bekliyoruz.',
            'courier_can_discount' => true,
            'courier_can_day_end' => true,
            'courier_can_collect' => false,
            'order_code_display' => 'siparis',
        ], ['occurred_at' => now()->subMinute()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        // 2) ESKİ build aynı bayide profili düzenler — o alanları HİÇ göndermez, üstelik damgası taze.
        $this->pushEvents($token, [
            $this->event('tenant_settings', 'upsert', $this->eskiIstemciAyarPayloadu(), ['occurred_at' => now()->toIso8601String()]),
        ])->assertJsonPath('results.0.status', 'applied');

        /** @var TenantSetting $satir */
        $satir = $this->asOwner(fn () => TenantSetting::query()->findOrFail($a['tenant']->id));

        // Eski istemcinin GÖNDERDİĞİ alan güncellenmiş olmalı (LWW hâlâ çalışıyor).
        $this->assertSame('Eski Build Su Bayii', $satir->business_name);

        // GÖNDERMEDİĞİ alanlar KORUNMALI — bu satırlar kırmızıysa "migration + eski istemci =
        // sessiz veri kaybı" sınıfı açıktır.
        $this->assertSame('TR330006100519786457841326', $satir->iban, 'Eski istemci IBAN\'ı sildi.');
        // v14 kolonları (2026-08-06). Kaybolmaları en görünür arıza olurdu: bayi kendi yazdığı
        // hatırlatma metnini bir gün açıp bakınca varsayılana dönmüş bulurdu.
        $this->assertSame('Mehmet Yılmaz', $satir->iban_owner_name, 'Eski istemci IBAN alıcı adını sildi.');
        $this->assertSame('Sayın *musteriadi*, *siparistutar* bekliyoruz.', $satir->reminder_template,
            'Eski istemci bayinin mesaj şablonunu sildi.');
        $this->assertTrue($satir->courier_can_discount, 'Eski istemci iskonto yetkisini varsayılana çekti.');
        $this->assertTrue($satir->courier_can_day_end, 'Eski istemci gün sonu yetkisini varsayılana çekti.');
        $this->assertFalse($satir->courier_can_collect, 'Eski istemci KAPATILMIŞ tahsilat yetkisini geri açtı.');
        $this->assertSame('siparis', $satir->order_code_display, 'Eski istemci kod tercihini varsayılana çekti.');
    }

    #[Test]
    public function guncel_istemci_acikca_null_gonderirse_alan_temizlenir(): void
    {
        // Koruma kuralının BEDELİ olmamalı: "temizle" niyeti hâlâ ifade edilebilir olmalı.
        // Ayrım anahtarın VARLIĞINDA — değerinde değil. Mevcut istemciler her zaman tam satır
        // gönderdiği için bu test onların davranışının DEĞİŞMEDİĞİNİ de kanıtlar.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->tenantSettingsUpsert([
            'iban' => 'TR330006100519786457841326',
            'courier_can_orders' => true,
        ], ['occurred_at' => now()->subMinute()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->pushEvents($token, [$this->tenantSettingsUpsert([
            'iban' => null,
            'courier_can_orders' => false,
        ], ['occurred_at' => now()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        /** @var TenantSetting $satir */
        $satir = $this->asOwner(fn () => TenantSetting::query()->findOrFail($a['tenant']->id));
        $this->assertNull($satir->iban, 'Açık null IBAN\'ı temizlemeliydi.');
        $this->assertFalse($satir->courier_can_orders, 'Açıkça kapatılan yetki açık kaldı.');
    }

    #[Test]
    public function ilk_yazimda_gonderilmeyen_alanlar_varsayilana_duser(): void
    {
        // Satır HENÜZ YOKKEN koruyacak bir değer de yoktur: yetkiler ürün varsayılanına,
        // kod tercihi 'musteri'ye düşmeli. Koruma kuralı bu yolu bozmamalı (NOT NULL kolonlar).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [
            $this->event('tenant_settings', 'upsert', $this->eskiIstemciAyarPayloadu()),
        ])->assertJsonPath('results.0.status', 'applied');

        /** @var TenantSetting $satir */
        $satir = $this->asOwner(fn () => TenantSetting::query()->findOrFail($a['tenant']->id));
        foreach (TenantSetting::KURYE_IZINLERI as $kolon => $varsayilan) {
            $this->assertSame($varsayilan, (bool) $satir->{$kolon}, "{$kolon} varsayılanı bozuldu.");
        }
        $this->assertSame('musteri', $satir->order_code_display);
        $this->assertNull($satir->iban);
    }

    // ----------------------------------------------------------------------------------
    // A) Basit varlıklar — aynı kural customer/product/adres için de geçmeli
    // ----------------------------------------------------------------------------------

    #[Test]
    public function eski_istemci_kara_listeyi_bilmedigi_icin_kaldiramaz(): void
    {
        // `blacklisted_at` 2026-08-01 migration'ıyla geldi. O tarihten eski bir build müşterinin
        // adını düzeltince kara liste SESSİZCE kalkardı: engellenen numara yeniden sipariş verir,
        // kimse fark etmez.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $id = (string) Str::uuid7();
        $damga = now()->subDay()->toIso8601String();

        $this->pushEvents($token, [$this->customerUpsert([
            'id' => $id, 'name' => 'Kara Listedeki', 'blacklisted_at' => $damga,
        ], ['occurred_at' => now()->subMinute()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        // ESKİ build: payload'da yalnız id + name + note.
        $this->pushEvents($token, [
            $this->event('customer', 'upsert', ['id' => $id, 'name' => 'Adı Düzeltildi', 'note' => null]),
        ])->assertJsonPath('results.0.status', 'applied');

        /** @var Customer $musteri */
        $musteri = $this->asOwner(fn () => Customer::query()->findOrFail($id));
        $this->assertSame('Adı Düzeltildi', $musteri->name);
        $this->assertNotNull($musteri->blacklisted_at, 'Eski istemci kara listeyi sessizce kaldırdı.');
    }

    #[Test]
    public function guncel_istemci_kara_listeden_cikarabilir(): void
    {
        // Kara listeden ÇIKARMA hâlâ ifade edilebilir olmalı: anahtar VAR, değeri null.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $id = (string) Str::uuid7();

        $this->pushEvents($token, [$this->customerUpsert([
            'id' => $id, 'name' => 'Kara Listedeki', 'blacklisted_at' => now()->subDay()->toIso8601String(),
        ], ['occurred_at' => now()->subMinute()->toIso8601String()])])->assertOk();

        $this->pushEvents($token, [$this->customerUpsert([
            'id' => $id, 'name' => 'Kara Listedeki', 'blacklisted_at' => null,
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->assertNull($this->asOwner(fn () => Customer::query()->findOrFail($id)->blacklisted_at));
    }

    #[Test]
    public function eski_istemci_urunun_bilmedigi_alanlarini_silmez(): void
    {
        // Aynı kural TÜM basit varlıklarda geçerli olmalı — kural varlık başına yazılsaydı bir
        // sonraki kolonu ekleyen kişi birini atlardı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $id = (string) Str::uuid7();

        $this->pushEvents($token, [$this->event('product', 'upsert', [
            'id' => $id, 'name' => '19L Damacana', 'unit_price_kurus' => 4500,
            'barcode' => '8690000000001', 'image_url' => 'https://x/y.jpg', 'is_active' => false,
        ], ['occurred_at' => now()->subMinute()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        // ESKİ build: yalnız ad + fiyat bilir.
        $this->pushEvents($token, [
            $this->event('product', 'upsert', ['id' => $id, 'name' => '19L Damacana Yeni', 'unit_price_kurus' => 5000]),
        ])->assertJsonPath('results.0.status', 'applied');

        $urun = $this->asOwner(fn () => Product::query()->findOrFail($id));
        $this->assertSame(5000, $urun->unit_price_kurus);
        $this->assertSame('8690000000001', $urun->barcode, 'Barkod silindi.');
        $this->assertSame('https://x/y.jpg', $urun->image_url, 'Görsel bağlantısı silindi.');
        $this->assertFalse($urun->is_active, 'Pasif ürün sessizce aktifleştirildi.');
    }

    #[Test]
    public function tureyen_kolon_koruma_filtresine_takilmaz(): void
    {
        // `phone_last10` payload'da OLMAYABİLİR (istemci göndermezse sunucu türetir) ama korunacak
        // bir alan DEĞİLDİR: numara değişince eşleşme anahtarı da değişmeli. Filtre bunu düşürseydi
        // arayan tanıma ESKİ numarayla eşleşmeye devam eder, yanlış müşteri kartını açardı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $musteriId = (string) Str::uuid7();
        $telefonId = (string) Str::uuid7();

        $this->pushEvents($token, [
            $this->customerUpsert(['id' => $musteriId, 'name' => 'Ahmet']),
            $this->event('customer_phone', 'upsert', [
                'id' => $telefonId, 'customer_id' => $musteriId, 'phone_e164' => '+905321112233',
            ], ['occurred_at' => now()->subMinute()->toIso8601String()]),
        ])->assertJsonPath('results.1.status', 'applied');

        // Numara değişti; istemci last10'u göndermiyor.
        $this->pushEvents($token, [
            $this->event('customer_phone', 'upsert', [
                'id' => $telefonId, 'customer_id' => $musteriId, 'phone_e164' => '+905339998877',
            ]),
        ])->assertJsonPath('results.0.status', 'applied');

        $telefon = $this->asOwner(fn () => CustomerPhone::query()->findOrFail($telefonId));
        $this->assertSame('+905339998877', $telefon->phone_e164);
        $this->assertSame('5339998877', $telefon->phone_last10, 'Eşleşme anahtarı eski numarada dondu.');
    }

    // ----------------------------------------------------------------------------------
    // E) Sürüm çarpıklığı korumaları — iki uçtaki sabitlerin bağı
    // ----------------------------------------------------------------------------------

    #[Test]
    public function mobil_batch_size_sunucunun_max_eventsini_asmaz(): void
    {
        // `SyncService::MAX_EVENTS` docblock'u bu bağı YAZIYOR ama hiçbir şey ZORLAMIYORDU:
        // "İki sabit AYRI DEPOLARDA yaşıyor ve birbirini göremiyor; tek korumamız bu yazılı bağ."
        // Oysa aynı MONOREPO'dalar — bağ makineyle zorlanabilir ve zorlanmalıdır. Bağ koparsa
        // (mobil batchSize büyür ya da sunucu MAX_EVENTS küçülür) HER push kalıcı 422 alır:
        // istemcinin ikili araması kuyruğu kilitlenmekten kurtarır ama her tur boşa gider.
        $yol = base_path('../mobile/lib/sync/sync_engine.dart');
        if (! is_file($yol)) {
            $this->markTestSkipped('Mobil kaynak bu ağaçta yok (yalnız API dağıtımı).');
        }

        $kaynak = (string) file_get_contents($yol);
        $this->assertSame(
            1,
            preg_match('/pushPending\(\{int batchSize = (\d+)\}\)/', $kaynak, $m),
            'pushPending imzası değişmiş — bu bekçi artık bağı GÖREMİYOR; deseni güncelle.'
        );

        $this->assertLessThanOrEqual(
            SyncService::MAX_EVENTS,
            (int) $m[1],
            'Mobil batchSize sunucunun MAX_EVENTS sınırını aşıyor: her push 422 alır.'
        );
    }

    // ----------------------------------------------------------------------------------
    // F) API SÜRÜMÜNÜN YANITTA GÖRÜNMESİ — çarpıklığı ÖLÇÜLEBİLİR kılan alan
    // ----------------------------------------------------------------------------------
    //
    // Yukarıdaki testlerin hepsi çarpıklığın ZARARINI önlüyor; bu bölüm çarpıklığın kendisini
    // GÖRÜNÜR kılıyor. 2026-08-09'da `config('app.version')` tanımlandı ama hiçbir yanıtta
    // okunmuyordu — o hâlde bir saha arızasında "sunucu mu eski, telefon mu" sorusunun cevabı
    // yoktu ve tek bilgi kaynağı sunucuya girip dosyaya bakmaktı.

    #[Test]
    public function senkron_yanitlari_api_surumunu_tasir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $surum = (string) config('app.version');

        // İKİ YÖN DE sınanır: telefon çoğu turda yalnız pull yapar (yazacak bir şeyi yoktur),
        // yalnız push'a koymak sürümü "yalnız yazan cihazlar görür" hâline getirirdi.
        $this->pullSince($token)->assertOk()->assertJsonPath('api_version', $surum);
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Sürüm Testi'])])
            ->assertOk()->assertJsonPath('api_version', $surum);
    }

    #[Test]
    public function surum_ucu_kimliksiz_okunur_ve_semver_bicimindedir(): void
    {
        // Kimliksiz: "canlıda hangi sürüm koşuyor" sorusunu soran taraf çoğu zaman token'ı
        // OLMAYAN taraftır (durum çubuğu, dağıtım sonrası doğrulama).
        $yanit = $this->getJson('/api/v1/version')->assertOk();
        $yanit->assertJsonPath('api_version', (string) config('app.version'));

        // server_time middleware'den gelmeye DEVAM etmeli: uç nokta kendi gövdesini kurduğu
        // için middleware'in "eksiği tamamla" davranışının bozulmadığını da kanıtlar.
        $this->assertArrayHasKey('server_time', $yanit->json());

        // BİÇİM SÖZLEŞMESİ: istemci tarafı sürümleri karşılaştırabilsin diye üç parçalı SemVer.
        // `1.0` ya da `v1.0.0` yazan bir vardiya karşılaştırmayı sessizce bozardı.
        $this->assertMatchesRegularExpression(
            '/^\d+\.\d+\.\d+$/',
            (string) config('app.version'),
            'API sürümü SemVer (MAJOR.MINOR.PATCH) olmalı — kural: CLAUDE.md → Sürümleme.'
        );
    }

    #[Test]
    public function mobil_istemci_api_surumunu_okuyor(): void
    {
        // "TANIMLI AMA BAĞLI DEĞİL" DESENİNE KARŞI BEKÇİ (bu depoda dört kez ödendi: kupon
        // kodları, `PushOzeti.beklemede`, `check_permissions.sh`, API sürümünün kendisi).
        // Sunucunun alanı göndermesi tek başına bir şey ifade etmez — okuyanı yoksa alan yoktur.
        // Aynı monorepo'da olduğumuz için bu bağ makineyle zorlanabilir; `batchSize` bekçisiyle
        // aynı desen.
        $yol = base_path('../mobile/lib/sync/sync_api.dart');
        if (! is_file($yol)) {
            $this->markTestSkipped('Mobil kaynak bu ağaçta yok (yalnız API dağıtımı).');
        }

        // `assertStringContainsString` DEĞİL, bilerek: o başarısızlıkta 12 KB'lık kaynak dosyayı
        // hata mesajına döker ve gerçek cümleyi görünmez kılar. Bekçinin değeri mesajındadır.
        $this->assertTrue(
            str_contains((string) file_get_contents($yol), "'api_version'"),
            'Mobil ayrıştırıcı api_version alanını okumuyor — sunucu gönderiyor, kimse bakmıyor.'
        );
    }

    #[Test]
    public function eski_istemci_kullanicinin_telefonunu_silmez(): void
    {
        // user_profile'da `name` ve `status` zaten mevcut değerden taşınıyordu; `phone` ise
        // `?? null` ile yazılıyordu — asimetrik. Kuryenin telefonu bayinin KENDİ personel
        // iletişim bilgisidir ve eski bir build'in profil yazımıyla kaybolmamalı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $kurye = $a['kurye'];

        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $kurye->id, 'name' => 'Mehmet Kurye', 'phone' => '+905321112233', 'status' => 'active',
        ], ['occurred_at' => now()->subMinute()->toIso8601String()])])
            ->assertJsonPath('results.0.status', 'applied');

        // ESKİ build: telefon alanını hiç bilmiyor.
        $this->pushEvents($token, [$this->userProfileUpsert(['id' => $kurye->id, 'name' => 'Mehmet K.'])])
            ->assertJsonPath('results.0.status', 'applied');

        /** @var User $taze */
        $taze = $this->asOwner(fn () => User::query()->findOrFail($kurye->id));
        $this->assertSame('Mehmet K.', $taze->name);
        $this->assertSame('+905321112233', $taze->phone, 'Eski istemci kurye telefonunu sildi.');
    }
}
