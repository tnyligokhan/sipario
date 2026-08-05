<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\TenantSetting;
use App\Models\User;
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
