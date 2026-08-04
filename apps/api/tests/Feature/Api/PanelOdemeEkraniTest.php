<?php

namespace Tests\Feature\Api;

use App\Abonelik\MasrafServisi;
use App\Abonelik\OdemeBildirimServisi;
use App\Abonelik\OdemeKayitServisi;
use App\Enums\BillingPeriod;
use App\Livewire\Panel\Bildirimler;
use App\Livewire\Panel\Odemeler;
use App\Models\AdminUser;
use App\Models\PaymentNotification;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use App\Support\Provisioning;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * PARA EKRANLARI · ÖDEMELER + HAVALE BİLDİRİMLERİ (ekran tarafı).
 *
 * Servis kurallarının kendisi App\Abonelik testlerindedir; burada EKRANIN o kurallara doğru
 * bağlandığı sınanır:
 *   - elle ödeme aboneliği uzatıyor mu, dönem seçimi gerçekten aylık/yıllık ayırıyor mu,
 *   - çift gönderim kalkanı gerçek mi (bileşen kararlı bir `provider_ref` üretiyor mu),
 *   - lira→kuruş dönüşümü esnaf yazımını kabul ediyor mu,
 *   - yetki kapısı bileşenin İÇİNDE mi ve reddedilen deneme denetime düşüyor mu,
 *   - denetim günlüğü KVKK-nötr mü (tutar/not YAZILMIYOR).
 *
 * NOT: bu testler yazıldı ama bu vardiyada KOŞULMADI (paralel ajanlar aynı test veritabanını
 * paylaşıyor).
 */
class PanelOdemeEkraniTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // ApiTestCase yalnız kendi listesini boşaltır; bu vardiyanın tabloları oradan gelmiyor.
        // `tenants` TRUNCATE CASCADE zaten addon_grants/payment_notifications'ı süpürür.
        DB::connection('pgsql_owner')->statement('TRUNCATE expenses RESTART IDENTITY CASCADE');
    }

    private function admin(string $rol = 'superadmin', string $email = 'para-super@sipario.test'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => $rol === 'superadmin' ? 'Para Süper' : 'Para Destek',
            'email' => $email, 'password' => 'panel-secret', 'role' => $rol,
        ]));
    }

    /** @return array<string, mixed> */
    private function bayi(string $prefix, ?BillingPeriod $donem = null): array
    {
        $veri = $this->makeTenant($prefix);

        Provisioning::asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($veri['tenant']->id)->update([
            'valid_until' => Carbon::create(2026, 8, 20, 12),
            'billing_period' => $donem?->value,
        ]));

        return $veri;
    }

    private function tenantOku(string $id): Tenant
    {
        return Provisioning::asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($id));
    }

    private function odemeSayisi(): int
    {
        return Provisioning::asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->count());
    }

    // --- Liste ---------------------------------------------------------------------------

    #[Test]
    public function odemeler_ekrani_kayitlari_toplami_ve_bos_durumu_gosterir(): void
    {
        $a = $this->bayi('a');
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        Livewire::test(Odemeler::class)
            ->assertOk()
            ->assertSee('Henüz ödeme kaydı yok. İlk ödemeyi sağ üstteki butonla ekleyebilirsin.');

        (new OdemeKayitServisi)->kaydet(
            tenantId: $a['tenant']->id,
            amountKurus: 59900,
            method: 'iban',
            coversPeriod: 'Ağustos 2026',
            period: BillingPeriod::Monthly,
            adminId: $super->id,
        );

        Livewire::test(Odemeler::class)
            ->assertSee('1 kayıt · toplam 599,00 ₺')
            ->assertSee('A Su Bayii')
            ->assertSee('Ağustos 2026')
            ->assertSee('IBAN');
    }

    #[Test]
    public function firma_aramasi_eslesmeyince_filtre_bos_durumu_cikar(): void
    {
        $a = $this->bayi('a');
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        (new OdemeKayitServisi)->kaydet(
            tenantId: $a['tenant']->id, amountKurus: 59900, method: 'iban',
            coversPeriod: 'Ağustos 2026', adminId: $super->id,
        );

        Livewire::test(Odemeler::class)
            ->set('arama', 'bulunamaz-firma')
            ->assertSee('Bu filtreyle eşleşen ödeme yok.')
            ->assertDontSee('Henüz ödeme kaydı yok.');
    }

    #[Test]
    public function baslik_toplami_sayfani_n_degil_tum_suzgecin_toplamidir(): void
    {
        // Sayfalamayı sunucuya taşırken en kolay yapılacak hata: başlıktaki toplamı paginator'dan
        // çıkarmak. O zaman ekran "bu sayfanın toplamı"nı gösterir ve kullanıcı yanılır.
        $a = $this->bayi('a');
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        for ($i = 1; $i <= 26; $i++) {
            (new OdemeKayitServisi)->kaydet(
                tenantId: $a['tenant']->id, amountKurus: 10000, method: 'iban',
                coversPeriod: 'Ağustos 2026', adminId: $super->id,
                occurredAt: Carbon::create(2026, 8, 4, 12)->subMinutes($i),
            );
        }

        // Sayfa 25 satır taşır; başlık 26 kaydın TAMAMINI söylemeli.
        Livewire::test(Odemeler::class)->assertSee('26 kayıt · toplam 2.600,00 ₺');
    }

    #[Test]
    public function arama_sayfa_disindaki_bayiyi_de_bulur(): void
    {
        // Eski davranışta süzme bellekte, yalnız çekilmiş satırların içinde yapılıyordu; sayfanın
        // (ve servisin 500'lük tavanının) dışında kalan bir bayi aratıldığında "kayıt yok" çıkıyordu.
        $a = $this->bayi('a');
        $b = $this->bayi('b');
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        // B'nin ödemesi EN ESKİ: sıralama tarihe göre tersten olduğu için ilk sayfada değil.
        (new OdemeKayitServisi)->kaydet(
            tenantId: $b['tenant']->id, amountKurus: 77700, method: 'elden',
            coversPeriod: 'Ağustos 2026', adminId: $super->id,
            occurredAt: Carbon::create(2026, 8, 1, 9),
        );

        for ($i = 1; $i <= 26; $i++) {
            (new OdemeKayitServisi)->kaydet(
                tenantId: $a['tenant']->id, amountKurus: 10000, method: 'iban',
                coversPeriod: 'Ağustos 2026', adminId: $super->id,
                occurredAt: Carbon::create(2026, 8, 4, 12)->subMinutes($i),
            );
        }

        Livewire::test(Odemeler::class)
            ->assertDontSee('B Su Bayii')      // ilk sayfada yok
            ->set('arama', 'B Su')
            ->assertSee('B Su Bayii')          // arama SQL'de: sayfanın dışından getirdi
            ->assertSee('1 kayıt · toplam 777,00 ₺');
    }

    #[Test]
    public function ay_suzgeci_secenekleri_yalnizca_odeme_gormus_aylardir(): void
    {
        $a = $this->bayi('a');
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        (new OdemeKayitServisi)->kaydet(
            tenantId: $a['tenant']->id, amountKurus: 59900, method: 'iban',
            coversPeriod: 'Ağustos 2026', adminId: $super->id,
            occurredAt: Carbon::create(2026, 8, 4, 12),
        );

        // Masraf BAŞKA bir aya girilir: ay süzgeci ödemelerin listesidir, gelir-gider raporunun
        // birleşik listesi değil — Temmuz seçeneği ÇIKMAMALI.
        (new MasrafServisi)->ekle(
            category: 'Reklam', amountKurus: 90000,
            spentOn: Carbon::create(2026, 7, 15), adminId: $super->id,
        );

        Livewire::test(Odemeler::class)
            ->assertSee('Ağustos 2026')
            ->assertDontSee('Temmuz 2026');
    }

    // --- Kayıt ---------------------------------------------------------------------------

    #[Test]
    public function ekrandan_odeme_kaydi_aboneligi_bir_ay_uzatir(): void
    {
        $a = $this->bayi('a', BillingPeriod::Monthly);
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        Livewire::test(Odemeler::class)
            ->call('odemeModalAc')
            ->assertSet('modalAcik', true)
            ->assertSee('abonelik bitişi 1 ay uzatılır')
            ->set('form.firmaId', $a['tenant']->id)
            ->set('form.tutar', '599,00')
            ->set('form.tarih', '2026-08-04')
            ->set('form.yontem', 'iban')
            ->set('form.donem', 'monthly')
            ->set('form.kapsam', '2026-08')
            ->call('odemeKaydet')
            ->assertSet('modalAcik', false)
            ->assertHasNoErrors();

        $tenant = $this->tenantOku($a['tenant']->id);
        $this->assertSame('active', $tenant->status->value);
        $this->assertSame('2026-09-20', $tenant->valid_until->toDateString(), 'Taban gelecekteki bitiştir, geri alınmaz.');
        $this->assertSame(1, $this->odemeSayisi());

        $odeme = Provisioning::asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->first());
        $this->assertSame(59900, $odeme->amount_kurus);
        $this->assertSame('monthly', $odeme->period);
        $this->assertSame('Ağustos 2026', $odeme->covers_period);
    }

    #[Test]
    public function yillik_secilince_bilgi_metni_ve_uzatma_bir_yil_olur(): void
    {
        $a = $this->bayi('a', BillingPeriod::Yearly);
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        Livewire::test(Odemeler::class)
            ->call('odemeModalAc')
            ->set('form.firmaId', $a['tenant']->id)      // firma seçimi bayinin dönemini getirir
            ->assertSet('form.donem', 'yearly')
            ->assertSee('abonelik bitişi 1 yıl uzatılır')
            ->set('form.tutar', '5988,00')
            ->set('form.tarih', '2026-08-04')
            ->set('form.kapsam', '2026-08')
            ->call('odemeKaydet')
            ->assertHasNoErrors();

        $this->assertSame('2027-08-20', $this->tenantOku($a['tenant']->id)->valid_until->toDateString());
    }

    #[Test]
    public function esnaf_yazimi_binlik_ayracli_tutar_dogru_kurusa_cevrilir(): void
    {
        $a = $this->bayi('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Odemeler::class)
            ->call('odemeModalAc')
            ->set('form.firmaId', $a['tenant']->id)
            ->set('form.tutar', '1.250,50')
            ->set('form.tarih', '2026-08-04')
            ->set('form.kapsam', '2026-08')
            ->call('odemeKaydet')
            ->assertHasNoErrors();

        $odeme = Provisioning::asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->first());
        $this->assertSame(125050, $odeme->amount_kurus);
    }

    #[Test]
    public function cozulemeyen_tutar_alanin_altinda_hata_verir_ve_kayit_olusmaz(): void
    {
        $a = $this->bayi('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Odemeler::class)
            ->call('odemeModalAc')
            ->set('form.firmaId', $a['tenant']->id)
            ->set('form.tutar', '12,34,56')     // birden çok virgül: belirsiz
            ->set('form.tarih', '2026-08-04')
            ->set('form.kapsam', '2026-08')
            ->call('odemeKaydet')
            ->assertHasErrors('form.tutar')
            ->assertSet('modalAcik', true, 'Hatalı gönderimde modal AÇIK kalmalı, girilen veri kaybolmamalı.');

        $this->assertSame(0, $this->odemeSayisi());

        // Reddedilen deneme denetime düşer; sebep KATEGORİKtir, girilen tutar DEĞİL.
        $red = Provisioning::asOwner(
            fn () => DB::connection('pgsql_owner')->table('panel_audit')->where('action', 'payment_manual_denied')->first()
        );
        $this->assertNotNull($red);
        $this->assertSame('gecersiz_tutar', $red->detail);
    }

    // --- Çift gönderim -------------------------------------------------------------------

    #[Test]
    public function bilesen_kararli_bir_idempotens_anahtari_uretir_ve_ayni_anahtar_ikinci_odeme_yaratmaz(): void
    {
        $a = $this->bayi('a', BillingPeriod::Monthly);
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        $ekran = Livewire::test(Odemeler::class)->call('odemeModalAc');
        $anahtar = $ekran->get('odemeAnahtari');

        $this->assertIsString($anahtar);
        $this->assertStringStartsWith('manual:', $anahtar, 'Anahtar modal açılırken doğmalı; null geçilirse idempotens KAYBOLUR.');

        $ekran->set('form.firmaId', $a['tenant']->id)
            ->set('form.tutar', '599,00')
            ->set('form.tarih', '2026-08-04')
            ->set('form.kapsam', '2026-08')
            ->call('odemeKaydet')
            ->assertHasNoErrors();

        $odeme = Provisioning::asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->first());
        $this->assertSame($anahtar, $odeme->provider_ref, 'Kayıt, bileşenin ürettiği anahtarı taşımalı.');

        // Aynı anahtarla gelen İKİNCİ çağrı (paralel istek/çift tıklama) ne yeni satır ne yeni uzatma üretir.
        (new OdemeKayitServisi)->kaydet(
            tenantId: $a['tenant']->id, amountKurus: 59900, method: 'iban',
            coversPeriod: 'Ağustos 2026', period: BillingPeriod::Monthly,
            adminId: $super->id, providerRef: $anahtar,
        );

        $this->assertSame(1, $this->odemeSayisi());
        $this->assertSame('2026-09-20', $this->tenantOku($a['tenant']->id)->valid_until->toDateString());
    }

    #[Test]
    public function kaydetmeden_sonra_dugmeye_tekrar_basmak_ikinci_odeme_uretmez(): void
    {
        $a = $this->bayi('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Odemeler::class)
            ->call('odemeModalAc')
            ->set('form.firmaId', $a['tenant']->id)
            ->set('form.tutar', '599,00')
            ->set('form.tarih', '2026-08-04')
            ->set('form.kapsam', '2026-08')
            ->call('odemeKaydet')
            ->call('odemeKaydet');   // modal kapandı, form sıfırlandı → ikinci çağrı doğrulamada durur

        $this->assertSame(1, $this->odemeSayisi());
    }

    // --- Yetki + denetim -----------------------------------------------------------------

    #[Test]
    public function destek_rolu_odeme_kaydedemez_ve_reddedilen_deneme_denetime_duser(): void
    {
        $a = $this->bayi('a');
        $destek = $this->admin('support', 'para-destek@sipario.test');
        $this->actingAs($destek, 'admin');

        Livewire::test(Odemeler::class)->assertOk()->assertDontSee('Ödeme Ekle');
        Livewire::test(Odemeler::class)->call('odemeModalAc')->assertForbidden();
        Livewire::test(Odemeler::class)->call('odemeKaydet')->assertForbidden();

        $this->assertSame(0, $this->odemeSayisi());

        $kayitlar = Provisioning::asOwner(
            fn () => DB::connection('pgsql_owner')->table('panel_audit')->where('action', 'payment_manual_denied')->get()
        );
        $this->assertCount(2, $kayitlar, 'Hem modal açma hem kaydetme denemesi günlüğe düşmeli.');
        $this->assertSame($destek->id, $kayitlar[0]->admin_user_id);
    }

    #[Test]
    public function denetim_gunlugu_tutar_ve_not_metnini_tasimaz(): void
    {
        $a = $this->bayi('a');
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        Livewire::test(Odemeler::class)
            ->call('odemeModalAc')
            ->set('form.firmaId', $a['tenant']->id)
            ->set('form.tutar', '1234,56')
            ->set('form.tarih', '2026-08-04')
            ->set('form.kapsam', '2026-08')
            ->set('form.not', 'Ofiste elden alındı')
            ->call('odemeKaydet');

        // REDDEDİLEN bir deneme de aynı sözleşmeye tabidir — sebep kodu yazılır, girdi yazılmaz.
        Livewire::test(Odemeler::class)
            ->call('odemeModalAc')
            ->set('form.firmaId', $a['tenant']->id)
            ->set('form.tutar', '98.765,43,21')
            ->set('form.tarih', '2026-08-04')
            ->set('form.kapsam', '2026-08')
            ->set('form.not', 'IBAN TR33 0006 1005 1978 6457 8413 26')
            ->call('odemeKaydet');

        $satirlar = Provisioning::asOwner(
            fn () => DB::connection('pgsql_owner')->table('panel_audit')->get()
        );

        $this->assertNotEmpty($satirlar);

        foreach ($satirlar as $satir) {
            $metin = $satir->action.'|'.(string) $satir->detail;
            foreach (['1234', '123456', 'Ofiste', '98', '765', 'TR33', 'IBAN'] as $sizinti) {
                $this->assertStringNotContainsString($sizinti, $metin, "panel_audit KVKK-nötr kalmalı; '{$sizinti}' sızdı.");
            }
        }
    }

    // --- Havale bildirimleri -------------------------------------------------------------

    private function bildirimAc(string $tenantId, int $kurus = 59900): PaymentNotification
    {
        return (new OdemeBildirimServisi)->olustur(
            tenantId: $tenantId, amountKurus: $kurus, method: 'iban',
            referenceCode: 'TEST-1234', declaredOn: Carbon::create(2026, 8, 2), note: 'Havale gönderdim',
        );
    }

    #[Test]
    public function bekleyen_bildirim_listelenir_ve_bos_durum_dogru_metni_verir(): void
    {
        $a = $this->bayi('a');
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Bildirimler::class)
            ->assertOk()
            ->assertSee('Bekleyen havale bildirimi yok.');

        $this->bildirimAc($a['tenant']->id);

        Livewire::test(Bildirimler::class)
            ->assertSee('A Su Bayii')
            ->assertSee('TEST-1234')
            ->assertSee('599,00 ₺');
    }

    #[Test]
    public function eslestirme_ekstredeki_gercek_tutari_yazar_ve_aboneligi_uzatir(): void
    {
        $a = $this->bayi('a', BillingPeriod::Monthly);
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        $bildirim = $this->bildirimAc($a['tenant']->id, 59900);

        Livewire::test(Bildirimler::class)
            ->call('eslestirAc', $bildirim->id)
            ->assertSet('kip', 'eslestir')
            ->assertSet('tutar', '599,00')
            ->set('tutar', '550,00')        // eksik havale: kayıt beyanı değil PARAYI yansıtır
            ->set('kapsam', '2026-08')
            ->set('donem', 'monthly')
            ->call('eslestir')
            ->assertHasNoErrors()
            ->assertSet('kip', null);

        $odeme = Provisioning::asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->first());
        $this->assertSame(55000, $odeme->amount_kurus);
        $this->assertSame('notify:'.$bildirim->id, $odeme->provider_ref);

        $kapali = Provisioning::asOwner(fn () => PaymentNotification::on('pgsql_owner')->find($bildirim->id));
        $this->assertSame('matched', $kapali->status);
        $this->assertSame('2026-09-20', $this->tenantOku($a['tenant']->id)->valid_until->toDateString());
    }

    #[Test]
    public function kapanmis_bildirim_kuyrukta_yoktur_ve_yeniden_islenemez(): void
    {
        $a = $this->bayi('a');
        $this->actingAs($this->admin(), 'admin');

        $bildirim = $this->bildirimAc($a['tenant']->id);

        Livewire::test(Bildirimler::class)
            ->call('eslestirAc', $bildirim->id)
            ->set('kapsam', '2026-08')
            ->call('eslestir');

        $this->assertSame(1, $this->odemeSayisi());

        // Kapanmış bildirim artık bekleyen kuyruğunda değildir → 404 (500 değil).
        Livewire::test(Bildirimler::class)->call('eslestirAc', $bildirim->id)->assertNotFound();
        $this->assertSame(1, $this->odemeSayisi());

        $red = Provisioning::asOwner(
            fn () => DB::connection('pgsql_owner')->table('panel_audit')
                ->where('action', 'payment_notification_match_denied')->first()
        );
        $this->assertNotNull($red, 'Kapanmış bildirimi yeniden işleme denemesi iz bırakmalı.');
        $this->assertSame('kapali_bildirim', $red->detail);
    }

    #[Test]
    public function reddetme_gerekce_ister_ve_odeme_kaydi_uretmez(): void
    {
        $a = $this->bayi('a');
        $this->actingAs($this->admin(), 'admin');

        $bildirim = $this->bildirimAc($a['tenant']->id);
        $oncekiBitis = $this->tenantOku($a['tenant']->id)->valid_until->toDateString();

        Livewire::test(Bildirimler::class)
            ->call('reddetAc', $bildirim->id)
            ->call('reddet')
            ->assertHasErrors('gerekce');

        Livewire::test(Bildirimler::class)
            ->call('reddetAc', $bildirim->id)
            ->set('gerekce', 'Ekstrede bu referansla havale yok.')
            ->call('reddet')
            ->assertHasNoErrors();

        $this->assertSame(0, $this->odemeSayisi());
        $this->assertSame($oncekiBitis, $this->tenantOku($a['tenant']->id)->valid_until->toDateString());
        $this->assertSame('rejected', Provisioning::asOwner(
            fn () => PaymentNotification::on('pgsql_owner')->find($bildirim->id)
        )->status);
    }

    #[Test]
    public function bozuk_uuid_404_verir_500_degil(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Bildirimler::class)->call('eslestirAc', 'bu-bir-uuid-degil')->assertNotFound();
        Livewire::test(Bildirimler::class)->call('reddetAc', 'bu-bir-uuid-degil')->assertNotFound();
    }

    #[Test]
    public function destek_rolu_bildirim_eslestiremez_ve_deneme_denetime_duser(): void
    {
        $a = $this->bayi('a');
        $destek = $this->admin('support', 'para-destek@sipario.test');
        $this->actingAs($destek, 'admin');

        $bildirim = $this->bildirimAc($a['tenant']->id);

        Livewire::test(Bildirimler::class)->call('eslestirAc', $bildirim->id)->assertForbidden();
        Livewire::test(Bildirimler::class)->call('reddetAc', $bildirim->id)->assertForbidden();

        $this->assertSame(0, $this->odemeSayisi());

        $eylemler = Provisioning::asOwner(
            fn () => DB::connection('pgsql_owner')->table('panel_audit')->pluck('action')->all()
        );
        $this->assertContains('payment_notification_match_denied', $eylemler);
        $this->assertContains('payment_notification_reject_denied', $eylemler);
    }
}
