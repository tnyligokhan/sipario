<?php

namespace Tests\Feature\Api;

use App\Livewire\Site\Hesap;
use App\Models\Customer;
use App\Models\TenantSetting;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * IBAN ALICI ADI + BORÇ HATIRLATMA ŞABLONU senkron sözleşmesi (kullanıcı isteği 2026-08-06).
 *
 * İkisi de `tenant_settings`in yeni kolonudur ve mesajın MÜŞTERİYE GİDEN yüzünü belirler:
 * alıcı adı yanlışsa havale tamamlanmaz, şablon inmezse bayi yazdığı metni telefonunda hiç
 * göremez. Bu yüzden round-trip (push → uygulanır → snapshot/delta ile geri gelir) burada
 * kanıtlanır — SyncDesignGapTest'in tenant_settings bölümünün aynı disiplini.
 *
 * "Anahtar YOK ≠ anahtar null" davranışı SurumCarpikligiTest'te ayrıca kilitlidir.
 */
class HatirlatmaSablonuTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private const SABLON = "Sayın *musteriadi*, merhaba.\n*siparistutar* ödemeniz bize ulaşmadı.\n\n*ibanodemebilgileri*\n\nTeşekkür ederiz.";

    #[Test]
    public function alici_adi_ve_sablon_push_edilir_snapshotta_ve_deltada_geri_gelir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->tenantSettingsUpsert([
            'business_name' => 'Aspendos Su',
            'iban' => 'TR330006100519786457841326',
            'iban_owner_name' => 'Mehmet Yılmaz',
            'reminder_template' => self::SABLON,
        ])])->assertJsonPath('results.0.status', 'applied');

        /** @var TenantSetting $satir */
        $satir = $this->asOwner(fn () => TenantSetting::query()->firstOrFail());
        $this->assertSame('Mehmet Yılmaz', $satir->iban_owner_name);
        $this->assertSame(self::SABLON, $satir->reminder_template,
            'Satır sonları ve yer tutucular OLDUĞU GİBİ saklanmalı — metin bayinin kendi cümlesidir.');

        // Taze kurulum snapshot'ı: yeni bir cihaz bu iki alanı görmeden mesajı kuramaz.
        $snap = $this->pullSince($token, 0);
        $ayar = collect($snap->json('entities.tenant_settings'))->first();
        $this->assertSame('Mehmet Yılmaz', $ayar['iban_owner_name']);
        $this->assertSame(self::SABLON, $ayar['reminder_template']);

        // KURULU cihaz yalnız DELTA çeker (sıra kodları vardiyasının dersi: sunucuda doğru duran
        // ama deltaya düşmeyen alan telefonda HİÇ görünmez).
        $this->pushEvents($token, [$this->tenantSettingsUpsert([
            'business_name' => 'Aspendos Su',
            'iban_owner_name' => 'Mehmet Yılmaz',
            'reminder_template' => self::SABLON,
        ], ['occurred_at' => now()->addMinute()->toIso8601String()])])->assertOk();

        $delta = collect($this->pullSince($token, 1)->json('changes'))
            ->where('entity_type', 'tenant_settings');
        $this->assertTrue($delta->pluck('payload.reminder_template')->filter()->isNotEmpty(),
            'delta yükünde reminder_template YOK');
        $this->assertTrue($delta->pluck('payload.iban_owner_name')->filter()->isNotEmpty(),
            'delta yükünde iban_owner_name YOK');
    }

    #[Test]
    public function bos_sablon_null_yazilir_yani_varsayilana_doner(): void
    {
        // İstemcide "şablonu boşalt" = "varsayılan metne dön" demektir. Boş dizeyle null iki ayrı
        // şey olsaydı, boşaltılan bir şablon istemcide "özel metin var ama boş" diye okunur ve
        // bayinin borçlusuna BOŞ bir WhatsApp mesajı hazırlanırdı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->tenantSettingsUpsert([
            'iban_owner_name' => '   ',
            'reminder_template' => '',
        ])])->assertJsonPath('results.0.status', 'applied');

        /** @var TenantSetting $satir */
        $satir = $this->asOwner(fn () => TenantSetting::query()->firstOrFail());
        $this->assertNull($satir->reminder_template);
        $this->assertNull($satir->iban_owner_name);
    }

    #[Test]
    public function asiri_uzun_sablon_reddedilir_ve_parti_bozulmaz(): void
    {
        // Kolon 1000 karakter. Sınıra dayanıp 22001 almak TÜM partiyi düşürürdü (panel test
        // vardiyasının dersi): aynı push'taki sipariş/tahsilat da yazılmazdı. Uygulayıcı önce
        // kendisi reddeder, savepoint yalnız BU olayı 'rejected' işaretler.
        //
        // KIRPMA YOK: yarım kalan bir metin bayinin müşterisine yarım gider ve bayi bunu ancak
        // müşteri sorunca öğrenir.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [
            $this->tenantSettingsUpsert(['reminder_template' => str_repeat('ş', 1001)]),
            $this->customerUpsert(['name' => 'Aynı partide, sağlam kayıt']),
        ])
            ->assertOk()
            ->assertJsonPath('results.0.status', 'rejected')
            ->assertJsonPath('results.1.status', 'applied');

        $this->assertSame(
            'Aynı partide, sağlam kayıt',
            $this->asOwner(fn () => Customer::query()->firstOrFail()->name)
        );
        $this->assertNull($this->asOwner(fn () => TenantSetting::query()->first()?->reminder_template));
    }

    #[Test]
    public function tam_sinirdaki_sablon_kabul_edilir(): void
    {
        // Sınır ÇOK BAYTLI karakterle de doğru sayılmalı: `strlen` kullansaydık 'ş' iki bayt
        // sayılır ve 500 harflik bir Türkçe metin sınıra takılırdı — bayi neden reddedildiğini
        // anlamazdı. Kolon `varchar(1000)` yani KARAKTER sayar; kapı da öyle saymalı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $sablon = str_repeat('ş', 1000);
        $this->pushEvents($token, [$this->tenantSettingsUpsert(['reminder_template' => $sablon])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->assertSame($sablon, $this->asOwner(fn () => TenantSetting::query()->firstOrFail()->reminder_template));
    }

    #[Test]
    public function bilinmeyen_yildizli_diziler_sunucuda_dokunulmadan_saklanir(): void
    {
        // WhatsApp'ta yıldız KALIN YAZI demektir. Sunucu yer tutucu denetimi yapmaz ve bilmediği
        // diziyi temizlemez — bayinin kendi vurgusunu ("*Önemli*") yemek metnini bozardı.
        // Çözümleme istemcidedir ve orada da aynı kural geçerlidir.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $metin = '*Önemli*: *musteriadi* için *bilinmeyenalan* — *ibanodemebilgileri*';
        $this->pushEvents($token, [$this->tenantSettingsUpsert(['reminder_template' => $metin])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->assertSame($metin, $this->asOwner(fn () => TenantSetting::query()->firstOrFail()->reminder_template));
    }

    // ----------------------------------------------------------------------------------
    // Site hesap paneli — aynı iki alan web'den de düzenlenebilmeli
    // ----------------------------------------------------------------------------------

    #[Test]
    public function site_hesap_paneli_iki_alani_senkron_yolundan_yazar(): void
    {
        // Doğrudan UPDATE olmaz (migration 802'nin dersi): değişiklik `sync_changes`e düşmezse
        // bayinin telefonuna HİÇ inmez ve LWW damgası ilerlemediği için bir sonraki cihaz yazımı
        // sessizce üstüne yazar. Yazma mobilin kullandığı AYNI yoldan geçmeli.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('sitesablon');

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->call('bolumSec', 'isletme')
            ->set('isletme.ibanAliciAdi', 'Mehmet Yılmaz')
            ->set('isletme.hatirlatmaSablonu', self::SABLON)
            ->call('isletmeKaydet')
            ->assertHasNoErrors();

        /** @var TenantSetting $ayar */
        $ayar = $this->asOwner(fn () => TenantSetting::on('pgsql_owner')->findOrFail($tenant->id));
        $this->assertSame('Mehmet Yılmaz', $ayar->iban_owner_name);
        $this->assertSame(self::SABLON, $ayar->reminder_template);

        $this->assertGreaterThan(0, $this->asOwner(fn () => DB::connection('pgsql_owner')
            ->table('sync_changes')->where('tenant_id', $tenant->id)
            ->where('entity_type', 'tenant_settings')->count()),
            'Değişiklik senkron günlüğüne düşmedi — telefona hiç inmez.');
    }

    #[Test]
    public function site_hesap_paneli_telefondan_girilen_ibani_silmez(): void
    {
        // Form bu iki alanı YAZAR ama IBAN'ı hiç göstermez; LWW upsert satırın tamamını
        // yazdığı için mevcut değerlerin taşınması ZORUNLUDUR (IsletmeFormu::ayarYaz).
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('siteiban');

        $this->asOwner(fn () => TenantSetting::on('pgsql_owner')->create([
            'tenant_id' => $tenant->id,
            'business_name' => 'Merkez Su',
            'iban' => 'TR330006100519786457841326',
            'receipt_note' => 'Teşekkürler',
            'updated_occurred_at' => now()->subDay(),
            'updated_device_id' => (string) Str::uuid7(),
        ]));

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->set('isletme.ibanAliciAdi', 'Mehmet Yılmaz')
            ->call('isletmeKaydet')
            ->assertHasNoErrors();

        /** @var TenantSetting $ayar */
        $ayar = $this->asOwner(fn () => TenantSetting::on('pgsql_owner')->findOrFail($tenant->id));
        $this->assertSame('Mehmet Yılmaz', $ayar->iban_owner_name);
        $this->assertSame('TR330006100519786457841326', $ayar->iban, 'Bayinin IBAN\'ı silinmemeliydi.');
        $this->assertSame('Teşekkürler', $ayar->receipt_note);
    }

    #[Test]
    public function site_hesap_paneli_asiri_uzun_sablonu_formda_reddeder(): void
    {
        // Hata FORMDA söylenmeli: yalnız sunucu kapısına bırakılsaydı olay 'rejected' olur ve
        // Livewire "kaydedildi" derdi — ekranın söyleyebileceği en kötü yalan.
        ['patron' => $patron] = $this->makeTenant('siteuzun');

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->set('isletme.hatirlatmaSablonu', str_repeat('ş', 1001))
            ->call('isletmeKaydet')
            ->assertHasErrors('isletme.hatirlatmaSablonu');
    }
}
