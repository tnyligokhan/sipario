<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\TenantDetail;
use App\Livewire\Site\Hesap;
use App\Livewire\Site\Register;
use App\Models\AdminUser;
use App\Models\User;
use App\Panel\TenantAdminService;
use App\Support\KullaniciAdiUretici;
use App\Support\Provisioning;
use Illuminate\Support\Facades\Mail;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * PATRONUN MOBİL GİRİŞ ADI: nasıl türetilir ve NEREDE GÖRÜNÜR (2026-08-31 kullanıcı kararı).
 *
 * İki ayrı arıza aynı anda kapatıldı ve ikisi de bu dosyada kilitlidir:
 *
 *  1. AD SABİTTİ. Her bayinin patronu 'patron'du. Teknik olarak meşrudu (ad bayi içinde tekildir)
 *     ama ayırt edici değildi ve bayiye kendi adını söylemiyordu.
 *  2. AD HİÇBİR EKRANDA YOKTU. Bayi onu yalnız hoş geldiniz postasında bir kez görüyordu ve o
 *     posta kayıt akışını DÜŞÜRMEDEN başarısız olabiliyor (`BayiPostacisi::postala` yutar). Yani
 *     postayı almayan bayi için giriş adı öğrenilemez bir bilgiydi.
 *
 * GÖRÜNÜRLÜK TESTLERİ EKRAN METNİNE BAKAR, alan değerine değil: hafızadaki ders ("ekran metni
 * sözleşmedir") tam tersini de gerektirir — `username` sütununu doğru yazıp ekrana basmamak
 * kullanıcının derdini çözmez. Testin de kullanıcının baktığı yere bakması gerekir.
 */
class KullaniciAdiTest extends ApiTestCase
{
    // ── Türetme ──────────────────────────────────────────────────────────────

    #[Test]
    public function ad_soyaddan_noktali_kullanici_adi_turer(): void
    {
        $sonuc = Provisioning::createTenantWithPatron(
            'Aslan Su', 'hasan@aslansu.test', 'password123', 'Hasan Aslan'
        );

        $this->assertSame('hasan.aslan', $sonuc['patron']->username);
    }

    #[Test]
    public function turkce_harfler_ascii_karsiligina_iner(): void
    {
        // DB CHECK'i (`users_username_check`) yalnız [a-z0-9._-] kabul eder. Türkçe harf
        // sızarsa INSERT 23514 ile düşer ve kayıt akışı hiçbir kullanıcı hatası olmadan
        // 500 verirdi — yani bu test bir biçim tercihini değil, akışın ayakta kalmasını sınar.
        $sonuc = Provisioning::createTenantWithPatron(
            'Çiğdem Su', 'cigdem@sipario.test', 'password123', 'Çiğdem Şahin İĞDIR'
        );

        $this->assertSame('cigdem.sahin.igdir', $sonuc['patron']->username);
        $this->assertMatchesRegularExpression('/^[a-z0-9._-]{3,60}$/', $sonuc['patron']->username);
    }

    #[Test]
    public function ad_yetersizse_epostanin_yerel_kismina_dusulur(): void
    {
        // "Ay" üç karakterin altında kalır (kısıtın alt sınırı 3). Dolgu harf uydurmak yerine
        // bir sonraki kaynağa geçilir: kimsenin tanımadığı bir giriş adı üretmek, adı hiç
        // üretmemekten kötüdür.
        $sonuc = Provisioning::createTenantWithPatron(
            'Ay Su', 'depo.merkez@sipario.test', 'password123', 'Ay'
        );

        $this->assertSame('depo.merkez', $sonuc['patron']->username);
    }

    #[Test]
    public function uzun_ad_kirpilir_ve_ayracla_bitmez(): void
    {
        $sonuc = Provisioning::createTenantWithPatron(
            'Uzun Su', 'uzun@sipario.test', 'password123', 'Abdurrahman Mehmet Ali Karaosmanoğlu'
        );

        $ad = (string) $sonuc['patron']->username;
        $this->assertLessThanOrEqual(24, mb_strlen($ad), 'Telefonda söylenecek ad kısa tutulur.');
        $this->assertMatchesRegularExpression('/^[a-z0-9._-]{3,60}$/', $ad);
        $this->assertStringEndsNotWith('.', $ad, 'Kırpma bir ayracın üstüne düşmüş olmamalı.');
    }

    #[Test]
    public function ayni_bayide_ayni_ad_ikinci_kez_uretilmez(): void
    {
        // Tekillik kısıtı (`users_tenant_username_unique`) bayi İÇİNDEdir. Üretici bunu kendisi
        // sormazsa çağıran ham 23505 görürdü.
        $a = $this->makeTenant('tk');
        $bayiId = (string) $a['tenant']->id;

        $uretici = new KullaniciAdiUretici('pgsql_owner');
        $ilk = Provisioning::asOwner(fn () => $uretici->patronIcin($bayiId, 'Kurye Bir', null));
        $this->assertSame('kurye.bir', $ilk);

        Provisioning::asOwner(fn () => User::factory()->kurye()->create([
            'tenant_id' => $bayiId, 'name' => 'Kurye Bir',
            'email' => 'kurye.bir@sipario.test', 'username' => 'kurye.bir',
        ]));

        $ikinci = Provisioning::asOwner(fn () => $uretici->patronIcin($bayiId, 'Kurye Bir', null));
        $this->assertSame('kurye.bir2', $ikinci);
    }

    #[Test]
    public function acikca_verilen_kullanici_adi_turetilmez(): void
    {
        // Çağıranın seçtiği adı sessizce başkasıyla değiştirmek, ekranda gösterilen ile
        // veritabanındakini ayırırdı — firma kodunda öğrenilen dersin aynısı.
        $sonuc = Provisioning::createTenantWithPatron(
            'Elle Su', 'elle@sipario.test', 'password123', 'Hasan Aslan', 'SahipHesap'
        );

        $this->assertSame('sahiphesap', $sonuc['patron']->username);
    }

    #[Test]
    public function mevcut_bayilerin_adi_degismez(): void
    {
        // ⚠️ GERİYE DÖNÜK DEĞİL. Kullanıcı adı mobil girişin kimliğidir; yaşayan bir hesabın
        // giriş adını bir deploy'la değiştirmek sahadaki telefonları kilitlerdi.
        $a = $this->makeTenant('eski');

        $this->assertSame('patron', $a['patron']->fresh()->username);
    }

    // ── Görünürlük ───────────────────────────────────────────────────────────

    #[Test]
    public function kayit_basari_ekrani_kullanici_adini_gosterir(): void
    {
        Mail::fake();

        Livewire::test(Register::class)
            ->set('isletme', 'Merkez Su Bayii')
            ->set('eposta', 'kayit@sipario.test')
            ->call('ileri')
            ->set('ad', 'Mehmet Yılmaz')
            ->set('parola', 'cokgizli8')
            ->call('ileri')
            ->set('kod', 'merkezbayi')
            ->set('kvkk', true)
            ->call('ileri')
            ->assertHasNoErrors()
            ->assertSet('adim', 3)
            ->assertSet('olusanKullanici', 'mehmet.yilmaz')
            ->assertSee('Giriş bilgileriniz')
            ->assertSee('mehmet.yilmaz')
            ->assertSee('merkezbayi');
    }

    #[Test]
    public function hesap_paneli_genel_bakista_giris_bilgileri_durur(): void
    {
        // Bayinin kendi hesap paneli — kullanıcının işaret ettiği yer ("Genel Bakış'ta gerekli
        // bilgiler gösterilsin"). Ad OTURUMDAKİ kullanıcıdan okunur.
        $a = $this->makeTenant('gbk');

        Livewire::actingAs($a['patron'], 'web')->test(Hesap::class)
            ->assertOk()
            ->assertSee('Giriş bilgileriniz')
            ->assertSee('Kullanıcı adı')
            ->assertSee($a['patron']->username)
            ->assertSee($a['tenant']->slug);
    }

    #[Test]
    public function hesap_paneli_oturumsuz_girildiginde_de_patronun_adini_bulur(): void
    {
        // Bu panele ödeme akışının ortasındaki `subscription_tenant_id` anahtarıyla, henüz giriş
        // yapmadan da girilebiliyor (bkz. Hesap::mount). O yolda `Auth::guard('web')` boştur ve
        // ekranın boş bir kullanıcı adı basması, sorunu çözmüş görünüp çözmemek olurdu.
        $a = $this->makeTenant('ots');

        session(['subscription_tenant_id' => $a['tenant']->id]);

        Livewire::test(Hesap::class)
            ->assertOk()
            ->assertSee('Giriş bilgileriniz')
            ->assertSee($a['patron']->username);
    }

    #[Test]
    public function panel_uye_detayi_patronun_kullanici_adini_gosterir(): void
    {
        // Operatör tarafı: kurulum bandı kapandıktan SONRA da cevap verebilmeli.
        $bayi = Provisioning::createTenantWithPatron(
            'Detay Su', 'detay@sipario.test', 'password123', 'Hasan Aslan'
        );

        $veri = app(TenantAdminService::class)->tenantDetail((string) $bayi['tenant']->id);

        $this->assertNotNull($veri);
        $this->assertSame('hasan.aslan', $veri['patron_username']);
    }

    #[Test]
    public function panel_uye_detayi_ekrani_kullanici_adi_satirini_basar(): void
    {
        $bayi = Provisioning::createTenantWithPatron(
            'Ekran Su', 'ekran@sipario.test', 'password123', 'Zeynep Kaya'
        );
        $this->actingAs($this->panelAdmini(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $bayi['tenant']->id])
            ->assertOk()
            ->assertSee('Kullanıcı adı')
            ->assertSee('zeynep.kaya');
    }

    private function panelAdmini(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Kimlik Admin', 'email' => 'kimlik@sipario.test',
            'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }
}
