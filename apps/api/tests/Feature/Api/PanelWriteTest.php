<?php

namespace Tests\Feature\Api;

use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Tenant;
use App\Panel\PanelWriteService;
use App\Panel\Telefon;
use App\Support\Provisioning;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use RuntimeException;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-3 · D3 — panelden MÜŞTERİ ve ÜRÜN yazma.
 *
 * Bu dosyanın taşıdığı üç iddia:
 *  1. Panelden girilen kayıt CİHAZA DÜŞER (sync deltasında görünür) — yeni bir yazma yolu değil,
 *     mobilin kullandığı yolun aynısı kullanıldığı için.
 *  2. Kırmızı çizgi KORUNUR — `sipario_panel` rolü iş verisine hâlâ yazamaz (42501); yazma RLS'li
 *     app bağlantısından geçer ve başka bayinin verisine uzanamaz.
 *  3. Düzenleme, formun göstermediği alanları SESSİZCE SİLMEZ (ChangeApplier'ın "satırın tamamını
 *     gönder" sözleşmesinin tuzağı) — kara liste ve ürün görseli korunur.
 */
class PanelWriteTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function yazici(): PanelWriteService
    {
        return new PanelWriteService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Yazan Admin', 'email' => 'yazan@sipario.test',
            'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /** Owner ile satır okuma (RLS dışı doğrulama). */
    private function musteriOku(string $id): ?Customer
    {
        return Provisioning::asOwner(fn () => Customer::query()->find($id));
    }

    #[Test]
    public function panelden_eklenen_musteri_telefon_ve_adresiyle_yazilir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $sonuc = $this->yazici()->musteriKaydet($a['tenant']->id, [
            'ad' => 'Ayşe Yılmaz',
            'not' => 'Kapıcıya bırak',
            'telefon' => '0532 111 22 33',
            'adres' => 'Şirinyalı Mah. 1497. Sk. No: 9',
            'bolge' => 'Muratpaşa',
        ], $admin->id);

        $this->assertSame('applied', $sonuc['durum']);

        $musteri = $this->musteriOku($sonuc['id']);
        $this->assertNotNull($musteri);
        $this->assertSame('Ayşe Yılmaz', $musteri->name);
        $this->assertSame($a['tenant']->id, $musteri->tenant_id);
        $this->assertNotNull($musteri->code, 'Müşteri sıra kodu panelden girişte de atanmalı.');

        $telefon = Provisioning::asOwner(fn () => DB::table('customer_phones')->where('customer_id', $sonuc['id'])->first());
        $this->assertSame('+905321112233', $telefon->phone_e164, 'Panelde yazılan numara E.164e normalleşmeli.');
        $this->assertSame('5321112233', $telefon->phone_last10);
        $this->assertTrue((bool) $telefon->is_primary);

        $adres = Provisioning::asOwner(fn () => DB::table('customer_addresses')->where('customer_id', $sonuc['id'])->first());
        $this->assertSame('Şirinyalı Mah. 1497. Sk. No: 9', $adres->address_text);
        $this->assertSame('Muratpaşa', $adres->region);
    }

    #[Test]
    public function panelden_yazilan_musteri_cihazin_senkron_deltasina_duser(): void
    {
        // BU TESTİN AMACI: panel yazması yeni bir yol değil, mobilin yolunun aynısıdır — dolayısıyla
        // sync_changes'e seq'li düşer ve telefon bir sonraki pull'da kaydı GÖRÜR.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        // Cihaz önce kendi kaydını yazar ve imleci alır.
        $push = $this->pushEvents($token, [$this->customerUpsert(['name' => 'Cihazdan'])])->assertOk();
        $imlec = (int) $push->json('current_seq');

        // Panel bir müşteri girer.
        $sonuc = $this->yazici()->musteriKaydet($a['tenant']->id, [
            'ad' => 'Panelden Girilen', 'telefon' => '05339998877',
        ], $admin->id);
        $this->assertSame('applied', $sonuc['durum']);

        // Cihaz imleçten sonrasını çeker.
        $pull = $this->pullSince($token, $imlec)->assertOk();
        $degisiklikler = $pull->json('changes');

        $musteriDegisimi = collect($degisiklikler)
            ->firstWhere('entity_id', $sonuc['id']);

        $this->assertNotNull($musteriDegisimi, 'Panelden girilen müşteri senkron deltasında OLMALI.');
        $this->assertSame('customer', $musteriDegisimi['entity_type']);
        $this->assertSame('upsert', $musteriDegisimi['op']);
        $this->assertSame('Panelden Girilen', $musteriDegisimi['payload']['name']);
        $this->assertGreaterThan($imlec, (int) $musteriDegisimi['seq'], 'Değişiklik imleçten SONRAKİ bir seq almalı.');

        // Telefon kaydı da aynı deltada.
        $telefonDegisimi = collect($degisiklikler)->firstWhere('entity_type', 'customer_phone');
        $this->assertNotNull($telefonDegisimi, 'Panelden girilen telefon da deltaya düşmeli.');
        $this->assertSame('+905339998877', $telefonDegisimi['payload']['phone_e164']);

        // Ve imleç ilerledi: sıfırdan kurulan bir cihaz da (snapshot) kaydı görür.
        $snapshot = $this->pullSince($token, 0)->assertOk();
        $adlar = collect($snapshot->json('entities.customer'))->pluck('name')->all();
        $this->assertContains('Panelden Girilen', $adlar, 'Yeni kurulan cihaz snapshot ile de görmeli.');
    }

    #[Test]
    public function panelden_yazilan_urun_de_senkron_deltasina_duser(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        $imlec = (int) $this->pushEvents($token, [$this->customerUpsert()])->json('current_seq');

        $sonuc = $this->yazici()->urunKaydet($a['tenant']->id, [
            'ad' => '19L Damacana', 'fiyat_kurus' => 4500, 'birim' => 'adet', 'barkod' => '8690000000001',
        ], $admin->id);
        $this->assertSame('applied', $sonuc['durum']);

        $degisim = collect($this->pullSince($token, $imlec)->json('changes'))
            ->firstWhere('entity_id', $sonuc['id']);

        $this->assertNotNull($degisim, 'Panelden girilen ürün senkron deltasında OLMALI.');
        $this->assertSame('product', $degisim['entity_type']);
        $this->assertSame(4500, (int) $degisim['payload']['unit_price_kurus']);
    }

    #[Test]
    public function musteri_duzenleme_kara_listeyi_sessizce_silmez(): void
    {
        // ChangeApplier sözleşmesi: gönderilmeyen alan null'lanır. Panel formu kara listeyi
        // göstermediği için, adı düzenlemek damgayı silmemeli (mobilde de aynı kural var).
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $ekle = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Kötü Müşteri'], $admin->id);
        $this->yazici()->musteriKaraListe($a['tenant']->id, $ekle['id'], true, $admin->id);
        $this->assertNotNull($this->musteriOku($ekle['id'])->blacklisted_at, 'Kara liste damgası yazılmalı.');

        $this->yazici()->musteriKaydet($a['tenant']->id, ['id' => $ekle['id'], 'ad' => 'Kötü Müşteri (düzeltildi)'], $admin->id);

        $musteri = $this->musteriOku($ekle['id']);
        $this->assertSame('Kötü Müşteri (düzeltildi)', $musteri->name);
        $this->assertNotNull($musteri->blacklisted_at, 'Ad düzenlemek kara liste damgasını SİLMEMELİ.');

        // Ve geri alınabilir.
        $this->yazici()->musteriKaraListe($a['tenant']->id, $ekle['id'], false, $admin->id);
        $this->assertNull($this->musteriOku($ekle['id'])->blacklisted_at);
    }

    #[Test]
    public function musteri_duzenleme_ikinci_telefon_satiri_uretmez(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $ekle = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Ayşe', 'telefon' => '05321112233'], $admin->id);
        $this->yazici()->musteriKaydet($a['tenant']->id, ['id' => $ekle['id'], 'ad' => 'Ayşe', 'telefon' => '05339998877'], $admin->id);

        $telefonlar = Provisioning::asOwner(fn () => DB::table('customer_phones')
            ->where('customer_id', $ekle['id'])->whereNull('deleted_at')->get());

        $this->assertCount(1, $telefonlar, 'Numara değişince yeni satır değil MEVCUT satır güncellenmeli.');
        $this->assertSame('+905339998877', $telefonlar[0]->phone_e164);
    }

    #[Test]
    public function ayni_saniyedeki_ardisik_duzenlemeler_kaybolmaz(): void
    {
        // REGRESYON: `updated_occurred_at` saniye çözünürlüklüdür ve LWW eşitlikte device_id'ye
        // düşer; panel yazmalarının cihazı olmadığı için iki yazma berabere kalır ve ikincisi
        // 'stale' olarak SESSİZCE yutulurdu. Destek "kaydet"e iki kez basınca ikincisi kaybolurdu.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $ekle = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Birinci'], $admin->id);

        foreach (['İkinci', 'Üçüncü', 'Dördüncü'] as $ad) {
            $sonuc = $this->yazici()->musteriKaydet($a['tenant']->id, ['id' => $ekle['id'], 'ad' => $ad], $admin->id);
            $this->assertSame('applied', $sonuc['durum'], "Ardışık düzenleme ({$ad}) uygulanmalı, bayat sayılmamalı.");
        }

        $this->assertSame('Dördüncü', $this->musteriOku($ekle['id'])->name);
    }

    #[Test]
    public function cihaz_daha_yeni_yazdiysa_panel_bayat_der_kaydettim_demez(): void
    {
        // Gerçek bir çakışmada panel SUSMAMALI: ChangeApplier bayat olayı sessizce yutar (mobilde
        // doğru davranış) ama formu az önce dolduran kullanıcıya "kaydedildi" demek yalan olur.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        $ekle = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Panelden'], $admin->id);

        // Cihaz İLERİ tarihli bir damgayla yazar (saat kayması / geç ulaşan offline yazım).
        $this->pushEvents($token, [$this->customerUpsert(
            ['id' => $ekle['id'], 'name' => 'Cihazdan (daha yeni)'],
            ['occurred_at' => now()->addHour()->toIso8601String()],
        )])->assertJsonPath('results.0.status', 'applied');

        $sonuc = $this->yazici()->musteriKaydet($a['tenant']->id, ['id' => $ekle['id'], 'ad' => 'Panel ezmeye çalışır'], $admin->id);

        $this->assertSame('stale', $sonuc['durum'], 'Daha yeni bir yazımın üstüne yazılamadığı SÖYLENMELİ.');
        $this->assertNotNull($sonuc['mesaj'], 'Kullanıcıya gösterilecek bir açıklama dönmeli.');
        $this->assertSame('Cihazdan (daha yeni)', $this->musteriOku($ekle['id'])->name, 'Cihazın yazımı korunmalı.');
        $this->assertSame(0, DB::connection('pgsql_panel')->table('panel_audit')
            ->where('action', 'customer_update')->count(), 'Uygulanmayan düzenleme denetime yazılmamalı.');
    }

    #[Test]
    public function panel_cihaz_kimligi_her_uuid7den_buyuktur(): void
    {
        // LWW eşitliği device_id METİN karşılaştırmasıyla çözülür. Panelin aynı saniyedeki bir
        // cihaz yazımıyla berabere kalmaması bu sıralamaya dayanır; kimlik değişirse burası kırılır.
        for ($i = 0; $i < 200; $i++) {
            $this->assertGreaterThan(
                (string) Str::uuid7(),
                PanelWriteService::PANEL_DEVICE_ID,
                'Panel cihaz kimliği her gerçek UUIDv7den büyük olmalı (LWW beraberlik bozucusu).'
            );
        }
    }

    #[Test]
    public function urun_duzenleme_gorsel_ve_aktifligi_korur(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        // Cihaz görselli bir ürün yazar.
        $urunId = (string) Str::uuid7();
        $this->pushEvents($token, [$this->event('product', 'upsert', [
            'id' => $urunId, 'name' => 'Damacana', 'unit_price_kurus' => 4500,
            'image_url' => 'https://cdn.example/damacana.jpg', 'is_active' => true,
        ])])->assertOk();

        // Panel ürünü pasifleştirir, sonra fiyatını düzenler.
        $this->yazici()->urunAktiflik($a['tenant']->id, $urunId, false, $admin->id);
        $this->yazici()->urunKaydet($a['tenant']->id, ['id' => $urunId, 'ad' => 'Damacana', 'fiyat_kurus' => 5000], $admin->id);

        $urun = Provisioning::asOwner(fn () => Product::query()->find($urunId));
        $this->assertSame(5000, $urun->unit_price_kurus);
        $this->assertSame('https://cdn.example/damacana.jpg', $urun->image_url, 'Panelde görsel alanı yok; düzenleme onu SİLMEMELİ.');
        $this->assertFalse($urun->is_active, 'Fiyat düzenlemek pasif ürünü diriltmemeli.');

        // Geri açılabilir.
        $this->yazici()->urunAktiflik($a['tenant']->id, $urunId, true, $admin->id);
        $this->assertTrue(Provisioning::asOwner(fn () => Product::query()->find($urunId))->is_active);
    }

    #[Test]
    public function her_yazma_panel_audite_kayit_birakir_ve_deger_yazmaz(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $m = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Gizli Ad', 'telefon' => '05321112233'], $admin->id);
        $this->yazici()->musteriKaydet($a['tenant']->id, ['id' => $m['id'], 'ad' => 'Gizli Ad 2'], $admin->id);
        $u = $this->yazici()->urunKaydet($a['tenant']->id, ['ad' => 'Damacana', 'fiyat_kurus' => 4500], $admin->id);
        $this->yazici()->urunAktiflik($a['tenant']->id, $u['id'], false, $admin->id);

        $kayitlar = DB::connection('pgsql_panel')->table('panel_audit')
            ->where('tenant_id', $a['tenant']->id)->orderBy('created_at')->get();

        $this->assertEqualsCanonicalizing(
            ['customer_create', 'customer_update', 'product_create', 'product_deactivate'],
            $kayitlar->pluck('action')->all()
        );
        $this->assertSame($admin->id, $kayitlar[0]->admin_user_id, 'Aktör admin kimliği kaydedilmeli.');

        // KVKK: denetim satırı yalnız eylem + hedef id taşır, DEĞER taşımaz.
        $tumDetay = $kayitlar->pluck('detail')->implode(' ');
        $this->assertStringNotContainsString('Gizli Ad', $tumDetay, 'Müşteri adı denetim günlüğüne yazılmamalı.');
        $this->assertStringNotContainsString('5321112233', $tumDetay, 'Telefon denetim günlüğüne yazılmamalı.');
        $this->assertStringContainsString('customer:'.$m['id'], $tumDetay);
    }

    #[Test]
    public function kilitli_bayide_panel_de_yazamaz(): void
    {
        // Kilit kararının tek sahibi sunucudur; paneli muaf tutmak kilidi anlamsızlaştırırdı.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)
            ->update(['status' => 'locked', 'locked_at' => now()->subMinute(), 'valid_until' => now()->subDay()]));

        $sonuc = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Kilitliyken'], $admin->id);

        $this->assertSame('locked', $sonuc['durum']);
        $this->assertNull($this->musteriOku($sonuc['id']), 'Kilitli bayide kayıt YAZILMAMALI.');
        $this->assertSame(0, DB::connection('pgsql_panel')->table('panel_audit')
            ->where('tenant_id', $a['tenant']->id)->count(), 'Gerçekleşmeyen eylem denetime yazılmamalı.');
    }

    #[Test]
    public function panel_yazmasi_baska_bayinin_verisine_uzanamaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $admin = $this->makeAdmin();

        $bMusteri = $this->yazici()->musteriKaydet($b['tenant']->id, ['ad' => 'B Müşterisi'], $admin->id);

        // A bayisi bağlamında B'nin müşteri kimliğiyle düzenleme denemesi: RLS satırı göstermez →
        // düzenleme değil YENİ KAYIT olur ve B'nin satırı DEĞİŞMEZ.
        $deneme = $this->yazici()->musteriKaydet($a['tenant']->id, ['id' => $bMusteri['id'], 'ad' => 'Ele geçirildi'], $admin->id);

        $this->assertNotSame($bMusteri['id'], $deneme['id'], 'Başka bayinin kimliği A bağlamında yeniden kullanılmamalı.');
        $this->assertSame('B Müşterisi', $this->musteriOku($bMusteri['id'])->name, "B'nin müşterisi panelden DEĞİŞTİRİLEMEMELİ.");
        $this->assertSame($b['tenant']->id, $this->musteriOku($bMusteri['id'])->tenant_id);
        $this->assertSame($a['tenant']->id, $this->musteriOku($deneme['id'])->tenant_id);

        // Kara liste yolu da uzanamaz (satır görünmediği için hata verir).
        $this->expectException(RuntimeException::class);
        $this->yazici()->musteriKaraListe($a['tenant']->id, $bMusteri['id'], true, $admin->id);
    }

    #[Test]
    public function kirmizi_cizgi_korunuyor_panel_rolu_hala_is_verisine_yazamaz(): void
    {
        // D3 yazma yeteneği getirdi ama `sipario_panel` rolünün grant matrisi DEĞİŞMEDİ.
        $this->makeTenant('a');

        foreach (['customers', 'products', 'orders', 'ledger_entries'] as $tablo) {
            try {
                DB::connection('pgsql_panel')->statement("UPDATE {$tablo} SET tenant_id = tenant_id");
                $this->fail("{$tablo} panel rolüyle UPDATE reddedilmeliydi.");
            } catch (QueryException $e) {
                $this->assertSame('42501', $e->getCode());
            }
        }
    }

    #[Test]
    public function bos_ad_ve_negatif_fiyat_reddedilir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        try {
            $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => '   '], $admin->id);
            $this->fail('Boş ad reddedilmeliydi.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('ad', mb_strtolower($e->getMessage()));
        }

        $this->expectException(RuntimeException::class);
        $this->yazici()->urunKaydet($a['tenant']->id, ['ad' => 'Damacana', 'fiyat_kurus' => -1], $admin->id);
    }

    #[Test]
    public function telefon_normalizasyonu_tr_bicimlerini_tek_bicime_indirir(): void
    {
        $this->assertSame('+905321112233', Telefon::e164('0532 111 22 33'));
        $this->assertSame('+905321112233', Telefon::e164('532-111-22-33'));
        $this->assertSame('+905321112233', Telefon::e164('+90 532 111 2233'));
        $this->assertSame('+905321112233', Telefon::e164('905321112233'));
        $this->assertSame('+49301234567', Telefon::e164('+49 30 1234567'), 'Uluslararası numara olduğu gibi korunmalı.');
        $this->assertNull(Telefon::e164('123'));
        $this->assertNull(Telefon::e164(''));
        $this->assertSame('5321112233', Telefon::son10('+90 532 111 22 33'));
    }
}
