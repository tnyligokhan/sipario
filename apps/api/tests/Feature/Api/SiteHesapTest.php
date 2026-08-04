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
 */
class SiteHesapTest extends ApiTestCase
{
    // ── Ödeme akışı ──────────────────────────────────────────────────────────

    #[Test]
    public function odeme_onaylar_isaretlenmeden_beyan_yazmaz(): void
    {
        ['patron' => $patron] = $this->makeTenant('onay');

        Livewire::actingAs($patron)->test(Subscribe::class)
            ->call('havaleBildir')
            ->assertHasErrors('onaylar');

        $this->assertSame(0, $this->asOwner(fn () => PaymentNotification::on('pgsql_owner')->count()));
    }

    #[Test]
    public function odeme_eksik_tek_onayda_bile_beyan_yazmaz(): void
    {
        // startCheckout'un sözleşmesi: ÜÇÜ DE zorunlu. İkisini işaretleyip geçmek mümkün olmamalı.
        ['patron' => $patron] = $this->makeTenant('eksik');

        Livewire::actingAs($patron)->test(Subscribe::class)
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

        Livewire::actingAs($patron)->test(Subscribe::class)
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

        Livewire::actingAs($patron)->test(Subscribe::class)
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
        Livewire::actingAs($patron)->test(Subscribe::class)->set('tutarKurus', 1);
    }

    #[Test]
    public function odeme_ekrani_tutari_plandan_okur(): void
    {
        // Sepet querystring'den okunur ama TUTAR oradan alınmaz: dönem yalnız HANGİ kalemin
        // satıldığını söyler, fiyatı `plans` tablosu belirler. Varsayılan dönem yıllıktır
        // (SubscriptionService::startCheckout ile aynı varsayılan).
        ['patron' => $patron] = $this->makeTenant('plan');
        $plan = new PlanDeposu('pgsql_owner');

        Livewire::actingAs($patron)->test(Subscribe::class)
            ->assertSet('donem', 'yearly')
            ->assertSet('tutarKurus', $plan->yillikKurus());
    }

    #[Test]
    public function odeme_ekraninda_kart_formu_ve_3ds_yoktur(): void
    {
        // Kart tahsilatı ERTELENDİ; yazılmayan kod sızdırmaz. Ekran kartı yalnız "Yakında" der.
        ['patron' => $patron] = $this->makeTenant('kart');

        Livewire::actingAs($patron)->test(Subscribe::class)
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

        Livewire::actingAs($patron)->test(Subscribe::class)
            ->assertDontSee('TR12 0001')
            ->assertSee('[Şirket IBAN]');
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

        $bilesen = Livewire::actingAs($patron)->test(Hesap::class)->call('bolumSec', 'fatura');

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
        Livewire::actingAs($patron)->test(Hesap::class)
            ->assertSee('Deneme sürümü')
            ->assertDontSee('Önizleme');

        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)->update([
            'status' => TenantStatus::Active->value, 'billing_period' => 'yearly',
            'valid_until' => now()->addMonths(8),
        ]));
        Livewire::actingAs($patron)->test(Hesap::class)
            ->assertSee('Sipario · Yıllık')
            ->assertDontSee('Deneme sürümü');
    }

    #[Test]
    public function hesap_fatura_pdf_indirme_vaadi_vermez(): void
    {
        // Fatura PDF'i HENÜZ YOK: sahte bir "indiriliyor" hissi verilmemeli.
        ['patron' => $patron] = $this->makeTenant('pdf');

        Livewire::actingAs($patron)->test(Hesap::class)
            ->call('bolumSec', 'fatura')
            ->assertDontSee('Tümünü indir')
            ->assertDontSee('indiriliyor');
    }

    #[Test]
    public function hesap_kurulum_listesi_gercek_duruma_bakar(): void
    {
        // Sabit `bitti: true` yazmak, hiçbir şey yapmamış bayiye "üç adımı tamamladın" demekti.
        ['patron' => $patron] = $this->makeTenant('kurulum');

        $kurulum = collect(Livewire::actingAs($patron)->test(Hesap::class)->instance()->kurulum());

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

        Livewire::actingAs($patron)->test(Hesap::class)
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

        Livewire::actingAs($patron)->test(Hesap::class)
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

        Livewire::actingAs($patron)->test(Hesap::class)
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
        Livewire::actingAs($patron)->test(Hesap::class)->set('bayiId', $komsu->id);
    }

    #[Test]
    public function cikis_oturumu_kapatir(): void
    {
        ['patron' => $patron] = $this->makeTenant('cikis');

        Livewire::actingAs($patron)->test(Hesap::class)
            ->call('cikis')
            ->assertRedirect(route('site.ana'));

        $this->assertFalse(Auth::guard('web')->check());
    }
}
