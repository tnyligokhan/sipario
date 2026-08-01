<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\CustomerImport;
use App\Livewire\Panel\Forms\MusteriForm;
use App\Livewire\Panel\Forms\UrunForm;
use App\Livewire\Panel\TenantDetail;
use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Tenant;
use App\Panel\PanelImportService;
use App\Panel\PanelWriteService;
use App\Support\Provisioning;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Livewire\Attributes\Validate;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use ReflectionClass;
use ReflectionProperty;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-3 — panel YAZMASININ ÜÇ KORUYUCUSU: uzunluk sınırı, LWW bayatlığı, abonelik kilidi.
 *
 * Üçünün ortak paydası ŞUDUR: yazma başarısız olduğunda panel BUNU SÖYLEMELİ. Sessiz başarısızlık
 * bu üründe en pahalı arıza türüdür — destek "kaydettim" der, telefonu kapatır, kayıt yoktur.
 *
 * `22001` TUZAĞI (araştırmacı bulgusu): kolon genişliğini aşan bir değer Postgres'te `22001` üretir
 * ve bu kod `SyncService::CLIENT_DATA_SQLSTATES` listesinde YOKTUR. Yani olay bazında `rejected`
 * olmaz; "beklenmedik altyapı hatası" sayılıp yeniden fırlatılır ve TÜM PARTİ geri alınır. Tek bir
 * uzun hücrenin 300 satırlık aktarımı düşürmesi buradan gelir. Savunma katmanlıdır ve bu dosya
 * katmanların HER BİRİNİN yerinde durduğunu sınar; en dıştaki katman formdur.
 */
class PanelWriteGuardTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function yazici(): PanelWriteService
    {
        return new PanelWriteService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Koruyucu', 'email' => 'koruyucu@sipario.test', 'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /** Bayiyi SÜRESİ DOLMUŞ yapar: status hâlâ aktif, yalnız valid_until geçmişte, locked_at NULL. */
    private function suresiniDoldur(string $tenantId): void
    {
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($tenantId)->update([
            'status' => 'active',
            'valid_until' => now()->subDay(),
            'locked_at' => null,
        ]));
    }

    // --- 1) Uzunluk: form katmanı DB'ye varmadan kesmeli ---------------------------------

    /**
     * Bir Livewire Form sınıfındaki `#[Validate]` kurallarından alan → azami uzunluk haritası.
     *
     * @param  class-string  $form
     * @return array<string, int>
     */
    private function formTavanlari(string $form): array
    {
        $tavanlar = [];

        foreach ((new ReflectionClass($form))->getProperties(ReflectionProperty::IS_PUBLIC) as $ozellik) {
            foreach ($ozellik->getAttributes(Validate::class) as $nitelik) {
                $kural = (string) ($nitelik->getArguments()[0] ?? '');
                if (preg_match('/max:(\d+)/', $kural, $es) === 1) {
                    $tavanlar[$ozellik->getName()] = (int) $es[1];
                }
            }
        }

        return $tavanlar;
    }

    #[Test]
    public function form_uzunluk_tavanlari_kolon_genisliklerini_asmaz(): void
    {
        // YAPISAL DENETİM — bu testin varlık sebebi somut bir kusurdur: `UrunForm::$barkod`
        // `max:64` iken `products.barcode` `varchar(32)` idi. Aradaki 32 karakterlik boşluğa düşen
        // her değer forma takılmadan Postgres'e ulaşır ve 22001 ile PARTİYİ düşürür.
        //
        // Tek tek değer denemek bu sınıfı kapatmaz (hangi alanı deneyeceğini bilmen gerekir);
        // kuralı şemayla karşılaştırmak kapatır. Yeni bir alan eklenip kolonundan geniş
        // tanımlandığında burada patlar.
        $eslesme = [
            MusteriForm::class => [
                'ad' => ['customers', 'name'],
                'telefon' => ['customer_phones', 'phone_e164'],
                'bolge' => ['customer_addresses', 'region'],
                // not/adres `text` kolonlarına gider — tavan yok, karşılaştırma anlamsız.
            ],
            UrunForm::class => [
                'ad' => ['products', 'name'],
                'birim' => ['products', 'unit'],
                'barkod' => ['products', 'barcode'],
            ],
        ];

        $denetlenen = 0;

        foreach ($eslesme as $form => $alanlar) {
            $tavanlar = $this->formTavanlari($form);

            foreach ($alanlar as $alan => [$tablo, $kolon]) {
                $this->assertArrayHasKey($alan, $tavanlar,
                    "{$form}::\${$alan} bir `max:` kuralı taşımalı — sınırsız alan 22001 üretir.");

                $genislik = DB::connection('pgsql_owner')->selectOne(
                    'SELECT character_maximum_length AS g FROM information_schema.columns
                     WHERE table_schema = \'public\' AND table_name = ? AND column_name = ?',
                    [$tablo, $kolon]
                );

                $this->assertNotNull($genislik?->g, "{$tablo}.{$kolon} genişliği okunamadı (kolon adı değişmiş olabilir).");

                $this->assertLessThanOrEqual((int) $genislik->g, $tavanlar[$alan],
                    "{$form}::\${$alan} tavanı ({$tavanlar[$alan]}) {$tablo}.{$kolon} genişliğini ({$genislik->g}) AŞIYOR; "
                    .'aradaki değerler forma takılmadan Postgres 22001 üretir ve senkron partisini düşürür.');

                $denetlenen++;
            }
        }

        $this->assertSame(6, $denetlenen, 'Beklenen sayıda alan denetlenmeli (eşleşme tablosu bayatlamış olabilir).');
    }

    #[Test]
    public function ekranda_asiri_uzun_deger_dogrulamada_kesilir_veritabanina_gitmez(): void
    {
        // Katmanın DAVRANIŞ tarafı: kullanıcı alanın altında hatayı görmeli, kayıt oluşmamalı ve
        // form AÇIK kalmalı (doldurduğu veriyi kaybetmesin).
        $a = $this->makeTenant('a');
        $this->actingAs($this->makeAdmin(), 'admin');

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc')
            ->set('musteriForm.ad', str_repeat('A', 200))
            ->set('musteriForm.bolge', str_repeat('B', 200))
            ->set('musteriForm.telefon', str_repeat('9', 100))
            ->call('musteriKaydet')
            ->assertHasErrors(['musteriForm.ad', 'musteriForm.bolge', 'musteriForm.telefon'])
            ->assertSet('musteriFormAcik', true);

        Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'urunler')
            ->call('urunFormAc')
            ->set('urunForm.ad', str_repeat('Ü', 200))
            ->set('urunForm.fiyat', '45')
            ->set('urunForm.barkod', str_repeat('8', 100))
            ->set('urunForm.birim', str_repeat('k', 100))
            ->call('urunKaydet')
            ->assertHasErrors(['urunForm.ad', 'urunForm.barkod', 'urunForm.birim']);

        $this->assertSame(0, $this->asOwner(fn () => Customer::query()->count()), 'Hiçbir müşteri yazılmamalı.');
        $this->assertSame(0, $this->asOwner(fn () => Product::query()->count()), 'Hiçbir ürün yazılmamalı.');
    }

    // --- 2) LWW bayatlığı: ekranda da yalan söylenmemeli ---------------------------------

    #[Test]
    public function ekranda_bayat_yazma_kaydettim_demez_ve_form_acik_kalir(): void
    {
        // PanelWriteTest bunu SERVİS seviyesinde kanıtlıyor. Ama kullanıcının gördüğü şey ekrandır:
        // servis 'stale' dönse bile bileşen bunu "kaydedildi" diye çizerse kusur aynen yaşar.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        $ekle = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Panelden'], $admin->id);

        // Cihaz İLERİ tarihli damgayla yazar (geç ulaşan çevrimdışı yazım / saat kayması).
        $this->pushEvents($token, [$this->customerUpsert(
            ['id' => $ekle['id'], 'name' => 'Cihazdan (daha yeni)'],
            ['occurred_at' => now()->addHour()->toIso8601String()],
        )])->assertJsonPath('results.0.status', 'applied');

        $this->actingAs($admin, 'admin');

        $bilesen = Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc', $ekle['id'])
            ->set('musteriForm.ad', 'Panel ezmeye çalışır')
            ->call('musteriKaydet');

        // Bildirim HATA olmalı ve "kaydedildi" DEMEMELİ.
        $bilesen->assertSet('bildirim.tur', 'hata')
            ->assertDontSee('Müşteri kaydedildi.')
            ->assertSet('musteriFormAcik', true);

        $mesaj = (string) ($bilesen->get('bildirim')['mesaj'] ?? '');
        $this->assertNotSame('', $mesaj, 'Kullanıcıya açıklama gösterilmeli.');
        $this->assertStringContainsString('tazele', mb_strtolower($mesaj), 'Mesaj kullanıcıya ne yapacağını söylemeli.');

        // Cihazın verisi korunmalı; panel ezmemiş olmalı.
        $ad = $this->asOwner(fn () => Customer::query()->withoutGlobalScopes()->where('id', $ekle['id'])->value('name'));
        $this->assertSame('Cihazdan (daha yeni)', $ad, 'Daha yeni cihaz yazımı korunmalı.');
    }

    #[Test]
    public function ekranda_ardisik_iki_kayit_ayni_saniyede_de_kaybolmaz(): void
    {
        // Damga ilerletme mekanizmasının (PANEL_DEVICE_ID + kendi damgasının üstüne çıkma) ekran
        // üzerinden karşılığı: destek kaydeder, hatayı görür, hemen düzeltir. İkinci kayıt aynı
        // saniyeye düşerse eskiden sessizce yutuluyordu.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->actingAs($admin, 'admin');

        $bilesen = Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc')
            ->set('musteriForm.ad', 'İlk Yazım')
            ->call('musteriKaydet');

        $bilesen->assertSet('bildirim.tur', 'ok');

        $musteriId = $this->asOwner(fn () => Customer::query()->where('name', 'İlk Yazım')->value('id'));
        $this->assertNotNull($musteriId);

        // AYNI saniyede düzeltme.
        $bilesen->call('musteriFormAc', $musteriId)
            ->set('musteriForm.ad', 'Düzeltilmiş Yazım')
            ->call('musteriKaydet')
            ->assertSet('bildirim.tur', 'ok');

        $adlar = $this->asOwner(fn () => Customer::query()->pluck('name')->all());
        $this->assertSame(['Düzeltilmiş Yazım'], $adlar, 'İkinci kayıt uygulanmalı ve kopya doğmamalı.');
    }

    // --- 3) Abonelik kilidi: süresi dolmuş bayi de yazmayı reddeder ----------------------

    #[Test]
    public function suresi_dolmus_bayide_panelden_yazilamaz(): void
    {
        // Mevcut testler status='locked' yolunu kapsıyor. Bu AYRI bir yoldur: status hâlâ 'active',
        // yalnız valid_until geçmişte ve locked_at NULL — kilit LAZY olarak push sırasında kurulur
        // (SyncService: locked_at = valid_until). Sahada aboneliklerin çoğu bu yolla kapanır
        // (kimse elle kilitlemez, süre dolar), yani asıl sık karşılaşılan hâl budur.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->suresiniDoldur($a['tenant']->id);

        $musteri = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Süre Dolmuşken'], $admin->id);
        $this->assertSame('locked', $musteri['durum'], 'Süresi dolmuş bayide panel yazamamalı.');

        $urun = $this->yazici()->urunKaydet($a['tenant']->id, ['ad' => 'Ürün', 'fiyat_kurus' => 4500], $admin->id);
        $this->assertSame('locked', $urun['durum']);

        $this->assertSame(0, $this->asOwner(fn () => Customer::query()->count()), 'Hiçbir müşteri yazılmamalı.');
        $this->assertSame(0, $this->asOwner(fn () => Product::query()->count()), 'Hiçbir ürün yazılmamalı.');

        // Uygulanmayan eylem denetime de yazılmamalı (denetim günlüğü olmayan işi göstermemeli).
        $this->assertSame(0, DB::connection('pgsql_panel')->table('panel_audit')
            ->whereIn('action', ['customer_create', 'product_create'])->count());
    }

    #[Test]
    public function suresi_dolmus_bayide_csv_aktarimi_hicbir_satir_yazmaz(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->suresiniDoldur($a['tenant']->id);

        $icerik = "ad;telefon;adres;bolge;not\n"
            ."Bir Müşteri;0532 111 22 33;Adres;Muratpaşa;\n"
            ."İki Müşteri;0533 222 33 44;Adres;Kepez;\n";

        $sonuc = (new PanelImportService('pgsql_panel'))->uygula($a['tenant']->id, $icerik, $admin->id);

        $this->assertSame('locked', $sonuc['durum'], 'Süresi dolmuş bayide aktarım reddedilmeli.');
        $this->assertSame(0, $sonuc['eklenen'], 'Kısmi yazma KALMAMALI (transaction geri sarılır).');
        $this->assertSame(0, $this->asOwner(fn () => Customer::query()->count()));
        $this->assertSame(0, DB::connection('pgsql_panel')->table('panel_audit')
            ->where('action', 'customer_import')->count(), 'Uygulanmayan aktarım denetime yazılmamalı.');
    }

    #[Test]
    public function suresi_dolmus_bayide_ekran_kullaniciya_sebebini_soyler(): void
    {
        // Kilit sunucunun kararıdır; kullanıcı "kaydedilmedi"yi değil NEDEN kaydedilmediğini
        // görmeli, yoksa destek ekibi hatayı kendi formunda arar.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->suresiniDoldur($a['tenant']->id);
        $this->actingAs($admin, 'admin');

        $bilesen = Livewire::test(TenantDetail::class, ['tenant' => $a['tenant']->id])
            ->call('sekmeSec', 'musteriler')
            ->call('musteriFormAc')
            ->set('musteriForm.ad', 'Süre Dolmuşken')
            ->call('musteriKaydet');

        $bilesen->assertSet('bildirim.tur', 'hata')
            ->assertDontSee('Müşteri kaydedildi.')
            ->assertSet('musteriFormAcik', true);

        $this->assertSame(0, $this->asOwner(fn () => Customer::query()->count()));

        // CSV aktarım ekranı da aynı kilidi gösterir.
        $ekran = Livewire::test(CustomerImport::class, ['tenant' => $a['tenant']->id])
            ->set('dosya', UploadedFile::fake()->createWithContent('musteriler.csv', "ad;telefon\nBir Müşteri;0532 111 22 33\n"))
            ->call('onizle');

        $ekran->call('uygula');
        $this->assertSame(0, $this->asOwner(fn () => Customer::query()->count()), 'Kilitli bayide aktarım ekranı da yazmamalı.');
    }
}
