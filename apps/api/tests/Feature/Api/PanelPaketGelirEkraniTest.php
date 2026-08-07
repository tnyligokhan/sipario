<?php

namespace Tests\Feature\Api;

use App\Abonelik\EkPaketServisi;
use App\Abonelik\MasrafServisi;
use App\Abonelik\OdemeKayitServisi;
use App\Livewire\Panel\GelirGider;
use App\Livewire\Panel\Paketler;
use App\Models\AddonGrant;
use App\Models\AddonPackage;
use App\Models\AdminUser;
use App\Models\Expense;
use App\Models\Plan;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use App\Support\Provisioning;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * PARA EKRANLARI · PAKETLER + GELİR-GİDER (ekran tarafı).
 *
 * Sınanan sözler:
 *   - "Yeni ücret bundan sonra girilecek ödemelerde varsayılan olur; geçmiş kayıtlar değişmez" —
 *     modal notunun DOĞRU olduğu (mevcut bayinin kotası aynen kalır).
 *   - "abonelik bitişi değişmez" — ek paket bir KAPASİTE satışıdır.
 *   - "Bedelsiz tanımlandığı için gelir kaydı oluşmaz" — kota artar, gelir satırı DOĞMAZ.
 *   - Gelir-gider ekranı ay sınırını KENDİ hesaplamaz; servisin verdiği anahtarı etiketler.
 *   - Yazma yetkisi bileşenin içindedir ve reddedilen deneme denetime düşer.
 *
 * NOT: bu testler yazıldı ama bu vardiyada KOŞULMADI (paralel ajanlar aynı test veritabanını
 * paylaşıyor).
 */
class PanelPaketGelirEkraniTest extends ApiTestCase
{
    private string $kontorPaketId;

    private string $kuryePaketId;

    protected function setUp(): void
    {
        parent::setUp();

        // Migration tohumu yerine BİLİNEN bir katalog: testler tohumun içeriğine bağlanmasın.
        DB::connection('pgsql_owner')->statement('TRUNCATE addon_packages, expenses RESTART IDENTITY CASCADE');

        $this->kontorPaketId = $this->paketEkle('credits', '100 oto-sıralama hakkı', 100, 14900);
        $this->kuryePaketId = $this->paketEkle('courier', '+1 kurye hesabı', 1, 7900);

        // Plan tek satırdır ve testler arası taşınır; bilinen değerlere çekiliyor.
        DB::connection('pgsql_owner')->table('plans')->update([
            'name' => 'Sipario',
            'price_monthly_kurus' => 59900,
            'price_yearly_kurus' => 598800,
            'trial_days' => 30,
            'route_credits_monthly' => 50,
            'courier_limit' => 3,
        ]);
    }

    private function paketEkle(string $tur, string $ad, int $adet, int $kurus, bool $aktif = true): string
    {
        $id = (string) Str::uuid7();

        DB::connection('pgsql_owner')->table('addon_packages')->insert([
            'id' => $id, 'type' => $tur, 'name' => $ad, 'quantity' => $adet,
            'price_kurus' => $kurus, 'active' => $aktif, 'created_at' => now(), 'updated_at' => now(),
        ]);

        return $id;
    }

    private function admin(string $rol = 'superadmin', string $email = 'paket-super@sipario.test'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => $rol === 'superadmin' ? 'Paket Süper' : 'Paket Destek',
            'email' => $email, 'password' => 'panel-secret', 'role' => $rol,
        ]));
    }

    private function tenantOku(string $id): Tenant
    {
        return Provisioning::asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($id));
    }

    // --- Plan ----------------------------------------------------------------------------

    #[Test]
    public function plan_karti_aylik_ve_yillik_ucreti_birlikte_gosterir(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)
            ->assertOk()
            ->assertSee('Abonelik Planı')
            ->assertSee('Aylık ücret')
            ->assertSee('599,00 ₺')
            ->assertSee('Yıllık ücret')      // tasarımda YOKTU, sunucuda var → eklendi
            ->assertSee('5.988,00 ₺')
            ->assertSee('30 gün');
    }

    #[Test]
    public function plan_duzenleme_yeni_fiyati_yazar_mevcut_bayinin_kotasina_dokunmaz(): void
    {
        $a = $this->makeTenant('a');
        $oncekiKontor = $this->tenantOku($a['tenant']->id)->route_credits_monthly;
        $oncekiKurye = $this->tenantOku($a['tenant']->id)->courier_limit;

        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)
            ->call('planModalAc')
            ->assertSet('planModalAcik', true)
            ->assertSee('Yeni ücret bundan sonra girilecek ödemelerde varsayılan olur; geçmiş kayıtlar değişmez.')
            ->set('planForm.aylik', '699,00')
            ->set('planForm.yillik', '6.988,00')
            ->set('planForm.hakAy', 250)
            ->call('planKaydet')
            ->assertHasNoErrors()
            ->assertSet('planModalAcik', false);

        $plan = Provisioning::asOwner(fn () => Plan::on('pgsql_owner')->first());
        $this->assertSame(69900, $plan->price_monthly_kurus);
        $this->assertSame(698800, $plan->price_yearly_kurus);
        $this->assertSame(250, $plan->route_credits_monthly);

        $tenant = $this->tenantOku($a['tenant']->id);
        $this->assertSame($oncekiKontor, $tenant->route_credits_monthly, 'Plan değişikliği MEVCUT bayinin kotasını değiştirmemeli.');
        $this->assertSame($oncekiKurye, $tenant->courier_limit);
    }

    #[Test]
    public function negatif_plan_ucreti_reddedilir(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)
            ->call('planModalAc')
            ->set('planForm.aylik', '-100')
            ->call('planKaydet')
            ->assertHasErrors('planForm.aylik');

        $this->assertSame(59900, Provisioning::asOwner(fn () => Plan::on('pgsql_owner')->first())->price_monthly_kurus);
    }

    // --- Ek paket kataloğu ---------------------------------------------------------------

    #[Test]
    public function ek_paket_eklenir_ve_katalogda_satista_gorunur(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)
            ->call('paketModalAc')
            ->assertSee('Ek Paket Ekle')
            ->set('paketForm.tur', 'credits')
            ->set('paketForm.ad', '500 oto-sıralama hakkı')
            ->set('paketForm.adet', 500)
            ->set('paketForm.ucret', '499,00')
            ->set('paketForm.aktif', '1')
            ->call('paketKaydet')
            ->assertHasNoErrors()
            ->assertSet('paketModalAcik', false)
            ->assertSee('500 oto-sıralama hakkı')
            ->assertSee('Satışta');

        $paket = Provisioning::asOwner(
            fn () => AddonPackage::on('pgsql_owner')->where('name', '500 oto-sıralama hakkı')->first()
        );
        $this->assertSame(49900, $paket->price_kurus);
        $this->assertSame(500, $paket->quantity);
        $this->assertTrue($paket->active);
    }

    #[Test]
    public function paket_pasife_alininca_rozet_degisir(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)
            ->call('paketModalAc', $this->kuryePaketId)
            ->assertSee('Paketi Düzenle')
            ->assertSet('paketForm.ad', '+1 kurye hesabı')
            ->assertSet('paketForm.ucret', '79,00')
            ->set('paketForm.aktif', '0')
            ->call('paketKaydet')
            ->assertHasNoErrors()
            ->assertSee('Pasif');

        $this->assertFalse(Provisioning::asOwner(
            fn () => AddonPackage::on('pgsql_owner')->find($this->kuryePaketId)
        )->active);
    }

    #[Test]
    public function bozuk_paket_kimligi_404_verir(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)->call('paketModalAc', 'uuid-degil')->assertNotFound();
        Livewire::test(Paketler::class)->call('paketModalAc', (string) Str::uuid7())->assertNotFound();
    }

    // --- Tanımlama -----------------------------------------------------------------------

    #[Test]
    public function ucretli_tanimlama_kotayi_artirir_gelir_yazar_ve_valid_untili_degistirmez(): void
    {
        $a = $this->makeTenant('a');
        $once = $this->tenantOku($a['tenant']->id);
        $onceKontor = $once->route_credits;
        $onceBitis = $once->valid_until?->toDateString();

        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)
            ->call('tanimlaModalAc')
            ->assertSee('abonelik bitişi değişmez')
            ->set('tanimlaForm.paketId', $this->kontorPaketId)
            ->set('tanimlaForm.firmaId', $a['tenant']->id)
            ->set('tanimlaForm.tahsil', 'iban')
            ->set('tanimlaForm.tutar', '149,00')
            ->set('tanimlaForm.tarih', '2026-08-04')
            ->call('tanimla')
            ->assertHasNoErrors()
            ->assertSet('tanimlaModalAcik', false);

        $sonra = $this->tenantOku($a['tenant']->id);
        $this->assertSame($onceKontor + 100, $sonra->route_credits);
        $this->assertSame($onceBitis, $sonra->valid_until?->toDateString(), 'Ek paket SÜRE satışı değildir.');

        $gelir = Provisioning::asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->first());
        $this->assertSame(14900, $gelir->amount_kurus);
        $this->assertSame('addon', $gelir->period);
    }

    #[Test]
    public function bedelsiz_tanimlama_kotayi_artirir_ama_gelir_kaydi_uretmez(): void
    {
        $a = $this->makeTenant('a');
        $onceKontor = $this->tenantOku($a['tenant']->id)->route_credits;

        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)
            ->call('tanimlaModalAc')
            ->set('tanimlaForm.paketId', $this->kontorPaketId)
            ->set('tanimlaForm.firmaId', $a['tenant']->id)
            ->set('tanimlaForm.tahsil', 'bedelsiz')
            ->assertSet('tanimlaForm.tutar', '0,00', 'Bedelsiz seçilince tutar 0\'a kilitlenmeli.')
            ->assertSee('Bedelsiz tanımlandığı için gelir kaydı oluşmaz.')
            ->set('tanimlaForm.tarih', '2026-08-04')
            ->call('tanimla')
            ->assertHasNoErrors();

        $this->assertSame($onceKontor + 100, $this->tenantOku($a['tenant']->id)->route_credits);
        $this->assertSame(0, Provisioning::asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->count()));

        $grant = Provisioning::asOwner(fn () => AddonGrant::on('pgsql_owner')->first());
        $this->assertSame(0, $grant->amount_kurus);
        $this->assertSame('bedelsiz', $grant->collection_method);
    }

    #[Test]
    public function bedelsiz_tutari_istemciden_gonderilse_bile_sifira_dusurulur(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        // Ekranda alan PASİF; istemci yine de bir değer gönderebilir. Karar sunucuda verilir.
        Livewire::test(Paketler::class)
            ->call('tanimlaModalAc')
            ->set('tanimlaForm.paketId', $this->kontorPaketId)
            ->set('tanimlaForm.firmaId', $a['tenant']->id)
            ->set('tanimlaForm.tahsil', 'bedelsiz')
            ->set('tanimlaForm.tutar', '999,00')
            ->set('tanimlaForm.tarih', '2026-08-04')
            ->call('tanimla')
            ->assertHasNoErrors();

        $this->assertSame(0, Provisioning::asOwner(fn () => AddonGrant::on('pgsql_owner')->first())->amount_kurus);
        $this->assertSame(0, Provisioning::asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->count()));
    }

    #[Test]
    public function bilesen_kararli_grant_anahtari_uretir_ve_ayni_anahtar_ikinci_tanimlama_yapmaz(): void
    {
        $a = $this->makeTenant('a');
        $onceKontor = $this->tenantOku($a['tenant']->id)->route_credits;
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        $ekran = Livewire::test(Paketler::class)->call('tanimlaModalAc');
        $anahtar = $ekran->get('tanimlamaAnahtari');

        $this->assertIsString($anahtar);
        $this->assertTrue(Str::isUuid($anahtar), 'Anahtar addon_grants.id olarak kullanılıyor; UUID olmalı.');

        $ekran->set('tanimlaForm.paketId', $this->kontorPaketId)
            ->set('tanimlaForm.firmaId', $a['tenant']->id)
            ->set('tanimlaForm.tahsil', 'iban')
            ->set('tanimlaForm.tarih', '2026-08-04')
            ->call('tanimla')
            ->assertHasNoErrors();

        $grant = Provisioning::asOwner(fn () => AddonGrant::on('pgsql_owner')->first());
        $this->assertSame($anahtar, (string) $grant->id, 'Kayıt, bileşenin ürettiği anahtarı taşımalı.');
        $this->assertSame($onceKontor + 100, $this->tenantOku($a['tenant']->id)->route_credits);

        // Aynı anahtarla gelen İKİNCİ çağrı (çift tıklama / paralel istek): ne yeni grant, ne yeni
        // gelir satırı, ne İKİNCİ KEZ kota artışı. Bu ödemeden daha kritik — kota geri alınamaz.
        (new EkPaketServisi)->tanimla(
            tenantId: $a['tenant']->id,
            paketId: $this->kontorPaketId,
            collectionMethod: 'iban',
            grantedOn: Carbon::create(2026, 8, 4),
            adminId: $super->id,
            grantId: $anahtar,
        );

        $this->assertSame(1, Provisioning::asOwner(fn () => AddonGrant::on('pgsql_owner')->count()));
        $this->assertSame(1, Provisioning::asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->count()));
        $this->assertSame($onceKontor + 100, $this->tenantOku($a['tenant']->id)->route_credits);
    }

    #[Test]
    public function tanimlama_modali_kapaninca_anahtar_sifirlanir(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)
            ->call('tanimlaModalAc')
            ->assertNotSet('tanimlamaAnahtari', null)
            ->call('tanimlaModalKapat')
            ->assertSet('tanimlamaAnahtari', null);
    }

    #[Test]
    public function kurye_paketi_kurye_limitini_artirir(): void
    {
        $a = $this->makeTenant('a');
        $onceLimit = $this->tenantOku($a['tenant']->id)->courier_limit;

        $this->actingAs($this->admin(), 'admin');

        Livewire::test(Paketler::class)
            ->call('tanimlaModalAc')
            ->set('tanimlaForm.paketId', $this->kuryePaketId)
            ->set('tanimlaForm.firmaId', $a['tenant']->id)
            ->assertSee('kurye hesabı daha açabilir hâle gelir')
            ->set('tanimlaForm.tahsil', 'elden')
            ->set('tanimlaForm.tarih', '2026-08-04')
            ->call('tanimla')
            ->assertHasNoErrors();

        $this->assertSame($onceLimit + 1, $this->tenantOku($a['tenant']->id)->courier_limit);
    }

    #[Test]
    public function destek_rolu_plan_duzenleyemez_paket_tanimlayamaz_ve_denemeleri_denetime_duser(): void
    {
        $this->makeTenant('a');
        $destek = $this->admin('support', 'paket-destek@sipario.test');
        $this->actingAs($destek, 'admin');

        Livewire::test(Paketler::class)->assertOk()->assertDontSee('Planı Düzenle');
        Livewire::test(Paketler::class)->call('planModalAc')->assertForbidden();
        Livewire::test(Paketler::class)->call('paketModalAc')->assertForbidden();
        Livewire::test(Paketler::class)->call('tanimlaModalAc')->assertForbidden();

        $this->assertSame(0, Provisioning::asOwner(fn () => AddonGrant::on('pgsql_owner')->count()));

        $eylemler = Provisioning::asOwner(
            fn () => DB::connection('pgsql_owner')->table('panel_audit')->pluck('action')->all()
        );
        $this->assertContains('plan_update_denied', $eylemler);
        $this->assertContains('addon_package_edit_denied', $eylemler);
        $this->assertContains('addon_grant_denied', $eylemler);
    }

    // --- Gelir-Gider ---------------------------------------------------------------------

    #[Test]
    public function aylik_ozet_gelir_gideri_ve_negatif_neti_gosterir(): void
    {
        $a = $this->makeTenant('a');
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        Livewire::test(GelirGider::class)
            ->assertOk()
            ->assertSee('Gelir ödemelerden otomatik hesaplanır')
            ->assertSee('Henüz kayıt yok. Ödemeler ve masraflar girildikçe aylık özet burada oluşur.');

        (new OdemeKayitServisi)->kaydet(
            tenantId: $a['tenant']->id, amountKurus: 59900, method: 'iban',
            coversPeriod: 'Ağustos 2026', adminId: $super->id,
            occurredAt: Carbon::create(2026, 8, 4, 12),
        );
        (new MasrafServisi)->ekle(
            category: 'Sunucu/Altyapı', amountKurus: 115000,
            spentOn: Carbon::create(2026, 8, 1), note: 'Hetzner aylık', adminId: $super->id,
        );

        Livewire::test(GelirGider::class)
            ->assertSee('Ağustos 2026')
            ->assertSee('599,00 ₺')
            ->assertSee('1.150,00 ₺')
            ->assertSee('−551,00 ₺')          // net eksi → işaretli ve --danger
            ->assertSee('Hetzner aylık');
    }

    #[Test]
    public function masraf_eklenince_secili_ay_o_aya_gecer_ve_kalem_listelenir(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(GelirGider::class)
            ->call('masrafModalAc')
            ->assertSet('modalAcik', true)
            ->set('form.tarih', '2026-07-15')
            ->set('form.tutar', '900')
            ->set('form.kategori', 'Reklam')
            ->set('form.not', 'Google Ads')
            ->call('masrafKaydet')
            ->assertHasNoErrors()
            ->assertSet('modalAcik', false)
            ->assertSet('seciliAy', '2026-07')
            ->assertSee('Temmuz 2026 masrafları')
            ->assertSee('Google Ads')
            ->assertSee('900,00 ₺');

        $masraf = Provisioning::asOwner(fn () => Expense::on('pgsql_owner')->first());
        $this->assertSame(90000, $masraf->amount_kurus);
        $this->assertSame('Reklam', $masraf->category);
    }

    #[Test]
    public function bilesen_kararli_masraf_anahtari_uretir_ve_ayni_anahtar_ikinci_kalem_yazmaz(): void
    {
        $super = $this->admin();
        $this->actingAs($super, 'admin');

        $ekran = Livewire::test(GelirGider::class)->call('masrafModalAc');
        $anahtar = $ekran->get('masrafAnahtari');

        $this->assertIsString($anahtar);
        $this->assertTrue(Str::isUuid($anahtar), 'Anahtar expenses.id olarak kullanılıyor; UUID olmalı.');

        $ekran->set('form.tarih', '2026-08-01')
            ->set('form.tutar', '1.150,00')
            ->set('form.kategori', 'Sunucu/Altyapı')
            ->call('masrafKaydet')
            ->assertHasNoErrors()
            ->assertSet('masrafAnahtari', null, 'Başarıdan sonra anahtar sıfırlanmalı.');

        $masraf = Provisioning::asOwner(fn () => Expense::on('pgsql_owner')->first());
        $this->assertSame($anahtar, (string) $masraf->id);

        // Aynı anahtarla ikinci çağrı: ne ikinci kalem, ne ikinci DENETİM kaydı (tekrar eden
        // çağrı yeni bir eylem değildir). Telafi yolu yok — expenses'ta UPDATE/DELETE izni yok.
        (new MasrafServisi)->ekle(
            category: 'Sunucu/Altyapı',
            amountKurus: 115000,
            spentOn: Carbon::create(2026, 8, 1),
            adminId: $super->id,
            expenseId: $anahtar,
        );

        $this->assertSame(1, Provisioning::asOwner(fn () => Expense::on('pgsql_owner')->count()));
        $this->assertSame(1, Provisioning::asOwner(
            fn () => DB::connection('pgsql_owner')->table('panel_audit')->where('action', 'expense_create')->count()
        ));
    }

    #[Test]
    public function katalog_disi_kategori_reddedilir_ve_kayit_olusmaz(): void
    {
        $this->actingAs($this->admin(), 'admin');

        Livewire::test(GelirGider::class)
            ->call('masrafModalAc')
            ->set('form.tarih', '2026-08-01')
            ->set('form.tutar', '100')
            ->set('form.kategori', 'reklam')       // küçük harf: katalogda YOK
            ->call('masrafKaydet')
            ->assertHasErrors('form.kategori');

        $this->assertSame(0, Provisioning::asOwner(fn () => Expense::on('pgsql_owner')->count()));
    }

    #[Test]
    public function destek_rolu_masraf_ekleyemez(): void
    {
        $destek = $this->admin('support', 'paket-destek@sipario.test');
        $this->actingAs($destek, 'admin');

        Livewire::test(GelirGider::class)->assertOk()->assertDontSee('Masraf Ekle');
        Livewire::test(GelirGider::class)->call('masrafModalAc')->assertForbidden();
        Livewire::test(GelirGider::class)->call('masrafKaydet')->assertForbidden();

        $this->assertSame(0, Provisioning::asOwner(fn () => Expense::on('pgsql_owner')->count()));

        $this->assertContains('expense_create_denied', Provisioning::asOwner(
            fn () => DB::connection('pgsql_owner')->table('panel_audit')->pluck('action')->all()
        ));
    }
}
