<?php

namespace Tests\Feature\Api;

use App\Abonelik\PlanDeposu;
use App\Enums\TenantStatus;
use App\Livewire\Site\Hesap;
use App\Livewire\Site\Subscribe;
use App\Models\PaymentNotification;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use App\Models\TenantSetting;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Livewire\Features\SupportLockedProperties\CannotUpdateLockedPropertyException;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * SİTENİN PARA YÜZEYİ — ödeme akışı (havale/elden beyanı) + bayinin hesap paneli.
 *
 * En pahalı iki kural burada sınanır:
 *   1. BEYAN ABONELİĞİ UZATMAZ. "Havale yaptım" diyen herkes bedava abone olamaz; `valid_until`
 *      yalnız panel operatörü ekstrede parayı görüp eşleştirdiğinde ilerler.
 *   2. BİR BAYİ BAŞKA BAYİNİN VERİSİNİ GÖRMEZ (kırmızı çizgi #1). Hesap panelindeki her sorgu
 *      oturumdaki tenant'a bağlıdır.
 *
 * `Livewire::actingAs($patron, 'web')` — SÜRÜCÜ AÇIKÇA VERİLİR, KALDIRMAYIN. Sürücüsüz çağrı
 * `auth()->guard(null)->setUser()` yapar, yani O ANKİ VARSAYILAN guard'a yazar; aynı testte daha
 * önce bir `auth:sanctum` isteği koşmuşsa `Authenticate` middleware'i varsayılanı kaydırmış olur
 * ve bileşenlerin `Auth::guard('web')` okuması BOŞ döner. Belirti tamamen yanıltıcıdır: eylem
 * sessizce erken çıkar, hata "kayıt yazılmadı" diye ürün mantığında aranır. `SiteEkipTest`te tam
 * bu oldu (2026-08-05) — bu dosyada bugün API isteği yok ama sıralamaya güvenmek, yarın buraya
 * bir istek ekleyen kişiye kurulmuş bir tuzaktır.
 */
class SiteHesapTest extends ApiTestCase
{
    // ── Ödeme akışı ──────────────────────────────────────────────────────────

    #[Test]
    public function odeme_onaylar_isaretlenmeden_beyan_yazmaz(): void
    {
        ['patron' => $patron] = $this->makeTenant('onay');

        Livewire::actingAs($patron, 'web')->test(Subscribe::class)
            ->call('havaleBildir')
            ->assertHasErrors('onaylar');

        $this->assertSame(0, $this->asOwner(fn () => PaymentNotification::on('pgsql_owner')->count()));
    }

    #[Test]
    public function odeme_eksik_tek_onayda_bile_beyan_yazmaz(): void
    {
        // startCheckout'un sözleşmesi: ÜÇÜ DE zorunlu. İkisini işaretleyip geçmek mümkün olmamalı.
        ['patron' => $patron] = $this->makeTenant('eksik');

        Livewire::actingAs($patron, 'web')->test(Subscribe::class)
            ->set('mesafeliSatis', true)
            ->set('onBilgilendirme', true)
            ->set('kvkk', false)
            ->call('havaleBildir')
            ->assertHasErrors('onaylar');

        $this->assertSame(0, $this->asOwner(fn () => PaymentNotification::on('pgsql_owner')->count()));
    }

    #[Test]
    public function havale_beyani_abonelik_uzatmaz(): void
    {
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('beyan');
        $once = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($tenant->id))->valid_until;

        Livewire::actingAs($patron, 'web')->test(Subscribe::class)
            ->set('mesafeliSatis', true)
            ->set('onBilgilendirme', true)
            ->set('kvkk', true)
            ->call('havaleBildir')
            ->assertHasNoErrors()
            ->assertSet('tesekkur', true);

        $bildirim = $this->asOwner(fn () => PaymentNotification::on('pgsql_owner')->firstOrFail());
        $this->assertSame(PaymentNotification::STATUS_PENDING, $bildirim->status);
        $this->assertSame('iban', $bildirim->method);
        $this->assertSame($tenant->id, $bildirim->tenant_id);

        // Abonelik DEĞİŞMEDİ ve hiçbir gerçek ödeme kaydı doğmadı.
        $sonra = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($tenant->id));
        $this->assertEquals($once?->toIso8601String(), $sonra->valid_until?->toIso8601String());
        $this->assertSame(0, $this->asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->count()));
    }

    #[Test]
    public function beyan_kabul_edilen_onay_surumlerini_kaydeder(): void
    {
        // startCheckout'un ikinci sözleşmesi: kabul edilen SÜRÜM saklanır. Artık `note` metnine
        // gömülmüyor — `payment_notifications.consent_version` + `consented_at` BİRİNCİ SINIF
        // kolonlar (SubscriptionService::manuelCheckout yazıyor). Not alanı yalnız kalem adıdır.
        ['patron' => $patron] = $this->makeTenant('surum');

        Livewire::actingAs($patron, 'web')->test(Subscribe::class)
            ->set('mesafeliSatis', true)->set('onBilgilendirme', true)->set('kvkk', true)
            ->call('eldenBildir')
            ->assertHasNoErrors();

        $bildirim = $this->asOwner(fn () => PaymentNotification::on('pgsql_owner')->firstOrFail());
        $this->assertSame('elden', $bildirim->method);

        $surum = (string) $bildirim->consent_version;
        $this->assertStringContainsString('distance_sales:'.config('subscription.legal.distance_sales_version'), $surum);
        $this->assertStringContainsString('preinfo:'.config('subscription.legal.preinfo_version'), $surum);
        $this->assertStringContainsString('kvkk:'.config('subscription.legal.kvkk_version'), $surum);

        // Sürüm ve zaman BİRLİKTE yolculuk eder (DB CHECK de bunu zorlar): "kabul edildi ama ne
        // zaman bilinmiyor" bir onay kaydı hukuken hiçbir işe yaramaz.
        $this->assertNotNull($bildirim->consented_at);

        // Not alanı artık onay metni TAŞIMAZ; sürüm kolondadır, notta kopyası kalmamalı.
        $this->assertStringNotContainsString('distance_sales:', (string) $bildirim->note);
    }

    #[Test]
    public function odeme_tutari_istemciden_alinamaz(): void
    {
        // Para SUNUCUDA hesaplanır; `$tutarKurus` #[Locked]. İstemci 1 kuruşa abone olamaz.
        ['patron' => $patron] = $this->makeTenant('tutar');

        $this->expectException(CannotUpdateLockedPropertyException::class);
        Livewire::actingAs($patron, 'web')->test(Subscribe::class)->set('tutarKurus', 1);
    }

    #[Test]
    public function odeme_ekrani_tutari_plandan_okur(): void
    {
        // Sepet querystring'den okunur ama TUTAR oradan alınmaz: dönem yalnız HANGİ kalemin
        // satıldığını söyler, fiyatı `plans` tablosu belirler. Varsayılan dönem yıllıktır
        // (SubscriptionService::startCheckout ile aynı varsayılan).
        ['patron' => $patron] = $this->makeTenant('plan');
        $plan = new PlanDeposu('pgsql_owner');

        Livewire::actingAs($patron, 'web')->test(Subscribe::class)
            ->assertSet('donem', 'yearly')
            ->assertSet('tutarKurus', $plan->yillikKurus());
    }

    #[Test]
    public function odeme_ekraninda_kart_formu_ve_3ds_yoktur(): void
    {
        // Kart tahsilatı ERTELENDİ; yazılmayan kod sızdırmaz. Ekran kartı yalnız "Yakında" der.
        ['patron' => $patron] = $this->makeTenant('kart');

        Livewire::actingAs($patron, 'web')->test(Subscribe::class)
            ->assertSee('Yakında')
            ->assertDontSee('Kart numarası')
            ->assertDontSee('3D Secure')
            ->assertDontSee('CVC');
    }

    #[Test]
    public function odeme_ekrani_sahte_iban_yazmaz(): void
    {
        // Tasarımdaki TR12 0001… örnek bir IBAN'dı. Yer tutucu görünür; uydurma hesap numarası YOK.
        ['patron' => $patron] = $this->makeTenant('iban');

        Livewire::actingAs($patron, 'web')->test(Subscribe::class)
            ->assertDontSee('TR12 0001')
            ->assertSee('[Şirket IBAN]');
    }

    #[Test]
    public function odeme_vazgec_gelinen_sekmeye_doner(): void
    {
        // Hesap panelinin Abonelik sekmesinden gelen bayi "Vazgeç" deyince oraya dönmeli; eskiden
        // sabit `site.fiyatlar`a düşüyordu ve bayi ne yapacağını bilmediği bir sayfada kalıyordu.
        ['patron' => $patron] = $this->makeTenant('geridonus');

        Livewire::actingAs($patron, 'web')->withQueryParams(['tur' => 'plan', 'geri' => 'abonelik'])
            ->test(Subscribe::class)
            ->assertSet('geri', 'abonelik')
            ->assertSee(route('site.hesap', ['bolum' => 'abonelik']), escape: false);
    }

    #[Test]
    public function odeme_vazgec_disaridan_verilen_adrese_gitmez(): void
    {
        /*
         * AÇIK YÖNLENDİRME KAPISI. `geri` bir ANAHTARdır, URL değil: dışarıdan gelen değer kapalı
         * listede yoksa varsayılana düşer. Bu sınanmazsa ödeme sayfasına bağlantı kurabilen herkes
         * bayiyi kendi oltalama sayfasına gönderebilirdi.
         */
        ['patron' => $patron] = $this->makeTenant('acikyonlendirme');

        Livewire::actingAs($patron, 'web')
            ->withQueryParams(['tur' => 'plan', 'geri' => 'https://kotu.example/sipario-odeme'])
            ->test(Subscribe::class)
            ->assertSet('geri', '')
            ->assertDontSee('kotu.example')
            ->assertSee(route('site.hesap'), escape: false);
    }

    // ── Hesap paneli ─────────────────────────────────────────────────────────

    #[Test]
    public function hesap_baska_bayinin_odemelerini_gostermez(): void
    {
        // KIRMIZI ÇİZGİ #1.
        ['tenant' => $bizim, 'patron' => $patron] = $this->makeTenant('bizim');
        ['tenant' => $komsu] = $this->makeTenant('komsu');

        $this->asOwner(function () use ($bizim, $komsu) {
            foreach ([[$bizim->id, 111100], [$komsu->id, 999900]] as [$tenantId, $tutar]) {
                SubscriptionPayment::on('pgsql_owner')->create([
                    'tenant_id' => $tenantId, 'amount_kurus' => $tutar, 'currency' => 'TRY',
                    'provider' => 'iban', 'provider_ref' => 'test:'.Str::uuid7(), 'status' => 'success',
                    'period' => 'yearly', 'occurred_at' => now(),
                ]);
            }
        });

        $bilesen = Livewire::actingAs($patron, 'web')->test(Hesap::class)->call('bolumSec', 'fatura');

        $this->assertCount(1, $bilesen->instance()->odemeler());
        $this->assertSame($bizim->id, $bilesen->instance()->odemeler()->first()->tenant_id);
        $bilesen->assertSee('1.111 ₺')->assertDontSee('9.999 ₺');
    }

    #[Test]
    public function hesap_durumu_gercek_veriden_gelir(): void
    {
        // Tasarımdaki "Önizleme: Deneme / Abone" anahtarı YAZILMADI; durum tenants.status'tur.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('durum');

        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)->update([
            'status' => TenantStatus::Trial->value, 'valid_until' => now()->addDays(11),
        ]));
        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->assertSee('Deneme sürümü')
            ->assertDontSee('Önizleme');

        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)->update([
            'status' => TenantStatus::Active->value, 'billing_period' => 'yearly',
            'valid_until' => now()->addMonths(8),
        ]));
        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->assertSee('Sipario · Yıllık')
            ->assertDontSee('Deneme sürümü');
    }

    #[Test]
    public function abonelikte_donem_karti_ayar_gibi_sunulmaz(): void
    {
        /*
         * ŞİKÂYETİN PARMAK İZİ (2026-08-05): aktif abonelikte panel başlığı "Dönemi seçin"di ve
         * altındaki kartlarda radyo düğmesi vardı; bayi bunu bir AYAR sanıp tıklıyor, ödeme
         * sayfasında buluyordu. Dönem bir tercih kaydı değil, ödeme anında belirlenen bir
         * sonuçtur — ekran bunu söylemek zorunda.
         */
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('donemmetni');

        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)->update([
            'status' => TenantStatus::Active->value, 'billing_period' => 'monthly',
            'valid_until' => now()->addMonths(3),
        ]));

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->call('bolumSec', 'abonelik')
            ->assertDontSee('Dönemi seçin')
            ->assertSee('ödeme adımıdır')
            // Hangi dönemin geçerli olduğu VURGUYLA değil, sözle söyleniyor.
            ->assertSee('Şu an bu dönemdesiniz');
    }

    #[Test]
    public function hak_bolumu_ek_kurye_paketini_katalogdan_gosterir(): void
    {
        /*
         * Kurye kotası SUNUCUDA gerçek (`KuryeKotasi` yeni hesabı `courier_limit`te durdurur) ve
         * katalogda ek kurye paketi SATIŞTA — ama bölüm yalnız oto-sıralama satıyordu, yani limite
         * takılan bayi ekranda hiçbir çıkış yolu görmüyordu.
         *
         * FİYAT SABİT YAZILMAZ: katalogdaki tutar ne ise ekrandaki odur. Katalog burada BİLİNEN bir
         * içeriğe çekiliyor (migration tohumuna bağlanmamak için — PanelPaketGelirEkraniTest deseni).
         */
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('kuryepaket');

        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)->update([
            'status' => TenantStatus::Active->value, 'valid_until' => now()->addMonths(6),
        ]));

        DB::connection('pgsql_owner')->statement('TRUNCATE addon_packages RESTART IDENTITY CASCADE');
        foreach ([['courier', '+1 kurye hesabı', 1, 7900], ['credits', '100 oto-sıralama hakkı', 100, 14900]] as [$tur, $ad, $adet, $kurus]) {
            DB::connection('pgsql_owner')->table('addon_packages')->insert([
                'id' => (string) Str::uuid7(), 'type' => $tur, 'name' => $ad, 'quantity' => $adet,
                'price_kurus' => $kurus, 'active' => true, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }

        $bilesen = Livewire::actingAs($patron, 'web')->test(Hesap::class)->call('bolumSec', 'hak');

        $bilesen->assertSee('Kurye hesapları')
            ->assertSee('79 ₺')      // katalogdaki kurye fiyatı
            ->assertSee('149 ₺');    // ve hak paketi — iki bölüm de aynı ekranda

        $this->assertCount(1, $bilesen->instance()->kuryePaketleri());
        $this->assertCount(1, $bilesen->instance()->hakPaketleri());
    }

    #[Test]
    public function hak_bolumu_denemede_satin_almayi_kapatir(): void
    {
        // Denemede tahsilat akışı yok; ek paket satmak henüz ödeme yapmamış bayiye fatura kesmek
        // olurdu. Kural kurye bölümü eklendikten sonra da geçerli.
        // (`makeTenant` AKTİF bayi üretir — deneme durumu burada açıkça kuruluyor.)
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('denemepaket');

        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)->update([
            'status' => TenantStatus::Trial->value, 'valid_until' => now()->addDays(21),
        ]));

        $bilesen = Livewire::actingAs($patron, 'web')->test(Hesap::class);

        $bilesen->call('bolumSec', 'hak')
            ->assertSee('aboneliği başlattıktan sonra satın alabilirsiniz')
            ->assertDontSee(route('subscription.subscribe', ['tur' => 'paket']), escape: false);

        // Denemedeki abonelik ekranı BOZULMADI: başlangıç seçimi orada gerçekten bir seçimdir,
        // "Aboneliği başlat" başlığı ve dönem kartları duruyor. (Abonedeki yeni metin denemeye
        // sızmamalı — `@unless` kapısı gerçekten kapalı mı, ekranı çizerek sınanıyor.)
        $bilesen->call('bolumSec', 'abonelik')
            ->assertSee('Aboneliği başlat')
            ->assertDontSee('Şu an bu dönemdesiniz');
    }

    #[Test]
    public function ekip_sekmesi_panele_bagli(): void
    {
        /*
         * `Site\Ekip` gömülü bir Livewire bileşenidir; sekme ÜÇ yere birden bağlanmadan çalışmaz
         * (BOLUMLER anahtarı + ikon haritası + partial). İkisi bağlanıp biri unutulursa ikon
         * haritası "Undefined array key" ile PATLAR — yani bu test bağın tamamını sınar.
         *
         * Kayıtlı ders ("kill-switch widget'ın içindeyse özellik test edilemez"): bir özelliğin
         * ağaca gerçekten bağlanmış olması, kodunun var olmasından ayrı bir olgudur ve ayrıca
         * sınanmalıdır.
         */
        ['patron' => $patron] = $this->makeTenant('ekipbag');

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->call('bolumSec', 'ekip')
            ->assertSet('bolum', 'ekip')
            ->assertSee('Ekip');
    }

    #[Test]
    public function hesap_bolumu_adresten_kapali_listeyle_okunur(): void
    {
        // `?bolum=` ödeme ekranındaki "Vazgeç"in geri dönüş kapısıdır; değer bir GÖRÜNÜM DOSYASI
        // YOLUNA dönüştüğü için kapalı liste olmak zorunda.
        ['patron' => $patron] = $this->makeTenant('bolumadres');

        Livewire::actingAs($patron, 'web')->withQueryParams(['bolum' => 'hak'])
            ->test(Hesap::class)->assertSet('bolum', 'hak');

        Livewire::actingAs($patron, 'web')->withQueryParams(['bolum' => '../../../etc/passwd'])
            ->test(Hesap::class)->assertSet('bolum', 'genel');
    }

    #[Test]
    public function hesap_fatura_pdf_indirme_vaadi_vermez(): void
    {
        // Fatura PDF'i HENÜZ YOK: sahte bir "indiriliyor" hissi verilmemeli.
        ['patron' => $patron] = $this->makeTenant('pdf');

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->call('bolumSec', 'fatura')
            ->assertDontSee('Tümünü indir')
            ->assertDontSee('indiriliyor');
    }

    #[Test]
    public function hesap_kurulum_listesi_gercek_duruma_bakar(): void
    {
        // Sabit `bitti: true` yazmak, hiçbir şey yapmamış bayiye "üç adımı tamamladın" demekti.
        ['patron' => $patron] = $this->makeTenant('kurulum');

        $kurulum = collect(Livewire::actingAs($patron, 'web')->test(Hesap::class)->instance()->kurulum());

        $this->assertTrue($kurulum->firstWhere('ad', 'İşletme hesabı açıldı')['bitti']);
        // makeTenant bir cihaz yaratır, müşteri/ürün/sipariş yaratmaz.
        $this->assertTrue($kurulum->firstWhere('ad', 'Uygulamayı telefonunuza kurdunuz')['bitti']);
        $this->assertFalse($kurulum->firstWhere('ad', 'İlk müşterinizi ekleyin')['bitti']);
        $this->assertFalse($kurulum->firstWhere('ad', 'İlk siparişi kaydedin')['bitti']);
        // Kurye hesabı VAR (makeTenant açıyor) — sayım gerçekten kullanıcı tablosundan geliyor.
        $this->assertTrue($kurulum->firstWhere('ad', 'Kurye hesabı oluşturun')['bitti']);
    }

    #[Test]
    public function isletme_bilgileri_fatura_alanlarini_senkron_yolundan_yazar(): void
    {
        // tenant_settings bir SENKRON VARLIĞIdır: doğrudan UPDATE değişikliği telefona indirmez
        // ve LWW damgasını ilerletmez. Yazma SyncService::push üzerinden gitmeli.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('ayar');

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->call('bolumSec', 'isletme')
            ->set('isletme.unvan', 'Merkez Su Bayii Ltd. Şti.')
            ->set('isletme.vkn', '1234567890')
            ->set('isletme.daire', 'Muratpaşa V.D.')
            ->set('isletme.adres', 'Şirinyalı Mah. 42. Sk. No:9/A')
            ->call('isletmeKaydet')
            ->assertHasNoErrors();

        $ayar = $this->asOwner(fn () => TenantSetting::on('pgsql_owner')->findOrFail($tenant->id));
        $this->assertSame('1234567890', $ayar->tax_number);
        $this->assertSame('Muratpaşa V.D.', $ayar->tax_office);
        $this->assertNotNull($ayar->updated_occurred_at, 'LWW damgası yazılmalı.');

        // Değişiklik senkron günlüğüne düştü mü — düşmediyse bayinin telefonuna HİÇ inmez.
        $this->assertGreaterThan(0, $this->asOwner(fn () => DB::connection('pgsql_owner')
            ->table('sync_changes')->where('tenant_id', $tenant->id)
            ->where('entity_type', 'tenant_settings')->count()));
    }

    #[Test]
    public function isletme_bilgileri_mevcut_profil_alanlarini_silmez(): void
    {
        // ProfileChangeApplier bir LWW UPSERT'tir: payload'da olmayan alan NULL'a çekilir.
        // Site yalnız dört fatura alanını gönderseydi telefondan girilen fiş notu/IBAN silinirdi.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('koru');

        $this->asOwner(fn () => TenantSetting::on('pgsql_owner')->create([
            'tenant_id' => $tenant->id,
            'business_name' => 'Merkez Su',
            'receipt_note' => 'Teşekkürler',
            'iban' => 'TR330006100519786457841326',
            'opens_at' => '08:00',
            'updated_occurred_at' => now()->subDay(),
            'updated_device_id' => (string) Str::uuid7(),
        ]));

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->set('isletme.vkn', '9876543210')
            ->call('isletmeKaydet')
            ->assertHasNoErrors();

        $ayar = $this->asOwner(fn () => TenantSetting::on('pgsql_owner')->findOrFail($tenant->id));
        $this->assertSame('9876543210', $ayar->tax_number);
        $this->assertSame('Teşekkürler', $ayar->receipt_note, 'Fiş notu silinmemeliydi.');
        $this->assertSame('TR330006100519786457841326', $ayar->iban, 'Bayinin IBAN\'ı silinmemeliydi.');
        $this->assertSame('08:00', $ayar->opens_at, 'Açılış saati silinmemeliydi.');
    }

    #[Test]
    public function isletme_bilgileri_baska_bayinin_firma_kodunu_alamaz(): void
    {
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('kodum');
        ['tenant' => $komsu] = $this->makeTenant('kodkomsu');

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->set('isletme.firmaKodu', $komsu->slug)
            ->call('isletmeKaydet')
            ->assertHasErrors('isletme.firmaKodu');

        $taze = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($tenant->id));
        $this->assertSame($tenant->slug, $taze->slug);
    }

    #[Test]
    public function hesap_bayi_kimligi_istemciden_degistirilemez(): void
    {
        // #[Locked]: istemci başka bir bayiyi gösteremez (kırmızı çizgi #1'in runtime kilidi).
        ['patron' => $patron] = $this->makeTenant('kilit');
        ['tenant' => $komsu] = $this->makeTenant('kilitkomsu');

        $this->expectException(CannotUpdateLockedPropertyException::class);
        Livewire::actingAs($patron, 'web')->test(Hesap::class)->set('bayiId', $komsu->id);
    }

    #[Test]
    public function cikis_oturumu_kapatir(): void
    {
        ['patron' => $patron] = $this->makeTenant('cikis');

        Livewire::actingAs($patron, 'web')->test(Hesap::class)
            ->call('cikis')
            ->assertRedirect(route('site.ana'));

        $this->assertFalse(Auth::guard('web')->check());
    }
}
