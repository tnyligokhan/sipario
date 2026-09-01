<?php

namespace Tests\Feature\Api;

use App\Abonelik\OdemeBildirimServisi;
use App\Models\PaymentNotification;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use App\Models\User;
use App\Payment\ConsentRequiredException;
use App\Payment\FakePaymentGateway;
use App\Payment\SubscriptionService;
use App\Support\DuplicateSlugException;
use App\Support\Provisioning;
use Illuminate\Database\QueryException;
use InvalidArgumentException;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * HUKUKİ ONAY KAYDI + KAYIT İMZASI — `manuelCheckout()` ve genişleyen `register()`.
 *
 * Buradaki iki kural bir uyuşmazlıkta savunma belgesidir:
 *   1. ÜÇ onay (mesafeli satış + ön bilgilendirme + KVKK) işaretlenmeden HİÇBİR beyan satırı
 *      doğmaz — kural ekranda değil SERVİSTE durur, çünkü ekran yarın değişir.
 *   2. Kabul edilen SÜRÜM ve ZAMAN birinci sınıf kolonlarda saklanır; serbest metinde değil.
 */
class AbonelikOnayTest extends ApiTestCase
{
    // ── Elle tahsilat checkout'u ─────────────────────────────────────────────

    #[Test]
    public function manuel_checkout_onay_surumunu_kolonlara_yazar(): void
    {
        ['tenant' => $tenant] = $this->makeTenant('onaykol');

        $bildirim = $this->service()->manuelCheckout(
            $tenant->id, 59900, 'iban', $this->onaylar(),
        );

        $satir = $this->asOwner(fn () => PaymentNotification::on('pgsql_owner')->findOrFail($bildirim->id));

        // `note` DEĞİL: sürüm sorgulanabilir bir kolonda durur (migration 005012'nin gerekçesi).
        $this->assertNull($satir->note);
        $this->assertNotNull($satir->consent_version);
        $this->assertStringContainsString('distance_sales:'.config('subscription.legal.distance_sales_version'), (string) $satir->consent_version);
        $this->assertStringContainsString('preinfo:'.config('subscription.legal.preinfo_version'), (string) $satir->consent_version);
        $this->assertStringContainsString('kvkk:'.config('subscription.legal.kvkk_version'), (string) $satir->consent_version);
        $this->assertNotNull($satir->consented_at, 'Zamansız onay ispatlanamaz.');
    }

    #[Test]
    public function manuel_checkout_onaysiz_hicbir_satir_yazmaz(): void
    {
        ['tenant' => $tenant] = $this->makeTenant('onaysiz');

        $this->expectException(ConsentRequiredException::class);
        try {
            $this->service()->manuelCheckout($tenant->id, 59900, 'iban', []);
        } finally {
            // Kural ekranın önünde değil, servisin İÇİNDE: Livewire atlansa bile satır doğmaz.
            $this->assertSame(0, $this->asOwner(fn () => PaymentNotification::on('pgsql_owner')->count()));
        }
    }

    #[Test]
    public function manuel_checkout_tek_onay_eksikse_de_reddeder(): void
    {
        ['tenant' => $tenant] = $this->makeTenant('eksikonay');

        $this->expectException(ConsentRequiredException::class);
        try {
            $this->service()->manuelCheckout($tenant->id, 59900, 'elden', [
                'distance_sales' => true, 'preinfo' => true, 'kvkk' => false,
            ]);
        } finally {
            $this->assertSame(0, $this->asOwner(fn () => PaymentNotification::on('pgsql_owner')->count()));
        }
    }

    #[Test]
    public function manuel_checkout_abonelik_uzatmaz(): void
    {
        // Beyan bir İDDİAdır. "Havale yaptım" diyen herkes bedava abone olamaz.
        ['tenant' => $tenant] = $this->makeTenant('uzatmaz');
        $once = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($tenant->id))->valid_until;

        $this->service()->manuelCheckout($tenant->id, 59900, 'iban', $this->onaylar());

        $sonra = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($tenant->id));
        $this->assertEquals($once?->toIso8601String(), $sonra->valid_until?->toIso8601String());
    }

    #[Test]
    public function manuel_checkout_odeme_saglayicisina_cikmaz(): void
    {
        // `startCheckout` anahtarsız iyzico'da patlıyordu; elle tahsilat yolunun gateway'e HİÇ
        // dokunmadığı kanıtlanmalı, yoksa kart tahsilatı açıldığı gün beyan akışı da ona bağlanır.
        ['tenant' => $tenant] = $this->makeTenant('gatewaysiz');
        $gateway = new FakePaymentGateway;

        (new SubscriptionService($gateway))->manuelCheckout($tenant->id, 59900, 'iban', $this->onaylar());

        $this->assertSame([], $gateway->initiated, 'Elle tahsilat sağlayıcıya HİÇ çıkmamalı.');
        $this->assertSame(0, $this->asOwner(fn () => SubscriptionPayment::on('pgsql_owner')->count()),
            'Beyan bir ödeme kaydı DOĞURMAZ; para kaydı ancak panel eşleştirmesinde oluşur.');
    }

    // ── Onay kolonlarının bütünlüğü ──────────────────────────────────────────

    #[Test]
    public function onaysiz_beyanda_damga_da_bos_kalir(): void
    {
        // Servis doğrudan çağrıldığında (panel/idari yol) onay kolonları NULL'dur; DB CHECK
        // "sürüm var ama zaman yok" satırını reddeder, buradaki normalizasyon o hatayı önler.
        ['tenant' => $tenant] = $this->makeTenant('damgasiz');

        $bildirim = (new OdemeBildirimServisi('pgsql_owner'))
            ->olustur($tenant->id, 59900, 'iban');

        $this->assertNull($bildirim->consent_version);
        $this->assertNull($bildirim->consented_at);
    }

    #[Test]
    public function surum_verilip_damga_verilmezse_damga_uretilir(): void
    {
        ['tenant' => $tenant] = $this->makeTenant('otodamga');

        $bildirim = (new OdemeBildirimServisi('pgsql_owner'))
            ->olustur($tenant->id, 59900, 'iban', consentVersion: 'kvkk:2026-07-15');

        $this->assertSame('kvkk:2026-07-15', $bildirim->consent_version);
        $this->assertNotNull($bildirim->consented_at);
    }

    #[Test]
    public function ayrisik_onay_satiri_veritabaninda_yasayamaz(): void
    {
        // Kolonların ayrışmasına karşı son emniyet KODDA değil ŞEMADA: 005012'deki CHECK.
        ['tenant' => $tenant] = $this->makeTenant('ayrisik');

        $this->expectException(QueryException::class);
        $this->asOwner(fn () => PaymentNotification::on('pgsql_owner')->create([
            'tenant_id' => $tenant->id, 'amount_kurus' => 100, 'method' => 'iban',
            'reference_code' => 'AYRISIK-1', 'declared_on' => now()->toDateString(),
            'status' => PaymentNotification::STATUS_PENDING,
            'consent_version' => 'kvkk:2026-07-15', 'consented_at' => null,
        ]));
    }

    // ── Kayıt imzası ─────────────────────────────────────────────────────────

    #[Test]
    public function kayit_firma_kodu_yetkili_ve_telefonu_tek_cagrida_yazar(): void
    {
        // Öncesinde bunlar kayıttan SONRA ikinci bir owner UPDATE'iyle düzeltiliyordu; bayi bir an
        // yanlış firma koduyla yaşıyordu.
        $sonuc = $this->service()->register(
            'Merkez Su Bayii', 'tekcagri@sipario.test', 'password123', '05551112233', true,
            slug: 'merkezbayi', patronAdi: 'Mehmet Yılmaz',
        );

        $tenant = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($sonuc['tenant']->id));
        $this->assertSame('merkezbayi', $tenant->slug);
        $this->assertSame('Mehmet Yılmaz', $tenant->contact_name);
        $this->assertSame('05551112233', $tenant->phone);

        $patron = $this->asOwner(fn () => User::on('pgsql_owner')->findOrFail($sonuc['patron']->id));
        $this->assertSame('Mehmet Yılmaz', $patron->name);
        $this->assertSame('05551112233', $patron->phone);
    }

    #[Test]
    public function kayit_yeni_alanlar_verilmezse_eski_davranisi_surdurur(): void
    {
        // GERİYE UYUMLULUK: CreateTenant komutu, TenantAdminService ve seeder'lar bu yoldan geçer.
        $sonuc = $this->service()->register('Merkez Su Bayii', 'eski@sipario.test', 'password123', null, true);

        $tenant = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($sonuc['tenant']->id));
        $this->assertSame('merkez-su-bayii', $tenant->slug, 'Kod addan türetilmeye devam etmeli.');
        $this->assertNull($tenant->contact_name, '"Patron" kelimesi yetkili adı diye yazılmamalı.');
        $this->assertSame('Patron', $sonuc['patron']->name);
    }

    #[Test]
    public function kayit_alinmis_firma_kodunda_yarim_bayi_birakmaz(): void
    {
        $this->service()->register('İlk Su Bayii', 'ilk@sipario.test', 'password123', null, true, slug: 'paylasilan');
        $oncekiSayi = $this->asOwner(fn () => Tenant::on('pgsql_owner')->count());

        try {
            $this->service()->register('İkinci Su Bayii', 'ikinci@sipario.test', 'password123', null, true, slug: 'paylasilan');
            $this->fail('Alınmış firma kodu DuplicateSlugException atmalıydı.');
        } catch (DuplicateSlugException) {
            // Transaction geri alındı: yarım bir bayi (tenant var, patron yok) KALMADI.
            $this->assertSame($oncekiSayi, $this->asOwner(fn () => Tenant::on('pgsql_owner')->count()));
            $this->assertSame(0, $this->asOwner(fn () => User::on('pgsql_owner')
                ->where('email', 'ikinci@sipario.test')->count()));
        }
    }

    #[Test]
    public function kayit_bozuk_firma_kodunu_sessizce_duzeltmez(): void
    {
        // Kullanıcının yazdığından BAŞKA bir kodu uygulamak, ekranda gösterilen kod ile
        // veritabanındakinin ayrışması demekti.
        $this->expectException(InvalidArgumentException::class);
        $this->service()->register('Bozuk Su', 'bozuk@sipario.test', 'password123', null, true, slug: 'Büyük Harf!');
    }

    #[Test]
    public function elle_bayi_acma_yolu_kirilmadi(): void
    {
        // TenantAdminService::createTenant ve CreateTenant komutunun kullandığı imza.
        $sonuc = Provisioning::createTenantWithPatron('Elle Su Bayii', 'elle@sipario.test', 'password123');

        $this->assertSame('elle-su-bayii', $sonuc['tenant']->slug);
        $this->assertSame('Patron', $sonuc['patron']->name);
        // Yetkili adı verilmedi → kullanıcı adı E-POSTANIN yerel kısmından türer. 'Patron'
        // varsayılanından türetmek eski sabit adı geri getirirdi (bkz. KullaniciAdiUretici).
        $this->assertSame('elle', $sonuc['patron']->username);
    }

    // ── Yardımcılar ──────────────────────────────────────────────────────────

    private function service(): SubscriptionService
    {
        return new SubscriptionService(new FakePaymentGateway);
    }

    /** @return array<string, bool> */
    private function onaylar(): array
    {
        return ['distance_sales' => true, 'preinfo' => true, 'kvkk' => true];
    }
}
