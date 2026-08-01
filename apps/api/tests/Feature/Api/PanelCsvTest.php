<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\CustomerImport;
use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\Tenant;
use App\Panel\Csv;
use App\Panel\PanelCsvExportService;
use App\Panel\PanelImportService;
use App\Panel\PanelWriteService;
use App\Support\Provisioning;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use RuntimeException;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-3 · D4 — müşteri CSV toplu aktarımı + müşteri/sipariş CSV dışa aktarımı.
 *
 * İki riskli yer var ve testlerin ağırlığı oradadır:
 *  1. DEDUP — dosya içinde ve mevcut kayıtlarla telefon tekrarı yakalanmazsa onboarding, bayinin
 *     müşteri listesini ikiye katlayarak biter.
 *  2. CSV ENJEKSİYONU — dışa aktarım hücreleri kullanıcı girdisidir; `=`, `+`, `@` ile başlayan
 *     bir ad, dosyayı açan kişinin makinesinde formül olarak çalışabilir.
 */
class PanelCsvTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function import(): PanelImportService
    {
        return new PanelImportService('pgsql_panel');
    }

    private function disa(): PanelCsvExportService
    {
        return new PanelCsvExportService('pgsql_panel');
    }

    private function yazici(): PanelWriteService
    {
        return new PanelWriteService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'CSV Admin', 'email' => 'csv@sipario.test',
            'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    private function csv(string ...$satirlar): string
    {
        return "ad;telefon;adres;bolge;not\n".implode("\n", $satirlar)."\n";
    }

    // --- İçe aktarım: önizleme ----------------------------------------------------------

    #[Test]
    public function onizleme_hicbir_sey_yazmaz_ve_ne_olacagini_soyler(): void
    {
        $a = $this->makeTenant('a');

        $onizleme = $this->import()->onizleme($a['tenant']->id, $this->csv(
            'Ayşe Yılmaz;0532 111 22 33;Şirinyalı Mah.;Muratpaşa;Kapıcıya bırak',
            'Mehmet Demir;0533 999 88 77;Kükürtlü Mah.;Osmangazi;',
        ));

        $this->assertSame(2, $onizleme['ozet']['eklenecek']);
        $this->assertSame(0, $onizleme['ozet']['atlanacak']);
        $this->assertSame(0, $onizleme['ozet']['hatali']);
        $this->assertSame('+905321112233', $onizleme['satirlar'][0]['telefon'], 'Önizlemede numara normalleşmiş görünmeli.');

        $this->assertSame(0, Provisioning::asOwner(fn () => Customer::query()->count()),
            'Önizleme HİÇBİR kayıt yazmamalı.');
    }

    #[Test]
    public function dosya_ici_telefon_tekrari_atlanir_ve_satir_numarasi_soylenir(): void
    {
        $a = $this->makeTenant('a');

        $onizleme = $this->import()->onizleme($a['tenant']->id, $this->csv(
            'Ayşe Yılmaz;0532 111 22 33;;;',
            'Ayşe Y.;+90 532 111 2233;;;',        // AYNI numara, farklı biçim
        ));

        $this->assertSame(1, $onizleme['ozet']['eklenecek']);
        $this->assertSame(1, $onizleme['ozet']['atlanacak']);
        $this->assertSame('atlanacak', $onizleme['satirlar'][1]['durum']);
        $this->assertStringContainsString('2. satırda', $onizleme['satirlar'][1]['aciklama'],
            'Kullanıcı hangi satırla çakıştığını görmeli.');
    }

    #[Test]
    public function mevcut_musterinin_telefonu_atlanir_ve_adiyla_soylenir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Kayıtlı Ayşe', 'telefon' => '05321112233'], $admin->id);

        $onizleme = $this->import()->onizleme($a['tenant']->id, $this->csv(
            'Ayşe Yılmaz;532 111 22 33;;;',
            'Yeni Müşteri;0533 999 88 77;;;',
        ));

        $this->assertSame(1, $onizleme['ozet']['eklenecek']);
        $this->assertSame(1, $onizleme['ozet']['atlanacak']);
        $this->assertStringContainsString('Kayıtlı Ayşe', $onizleme['satirlar'][0]['aciklama'],
            'Kiminle çakıştığı yazmalı.');
    }

    #[Test]
    public function hatali_satirlar_satir_numarasiyla_isaretlenir(): void
    {
        $a = $this->makeTenant('a');

        $onizleme = $this->import()->onizleme($a['tenant']->id, $this->csv(
            ';0532 111 22 33;;;',            // 2. satır: ad boş
            'X;0533 999 88 77;;;',           // 3. satır: ad çok kısa
            'Geçerli Ad;123;;;',             // 4. satır: telefon okunamadı
            'Sorunsuz Müşteri;;;;',          // 5. satır: telefonsuz ama geçerli
        ));

        $this->assertSame(3, $onizleme['ozet']['hatali']);
        $this->assertSame(1, $onizleme['ozet']['eklenecek']);

        $this->assertSame(2, $onizleme['satirlar'][0]['satir'], 'Başlık satırı sayıldığı için ilk veri satırı 2 numaralıdır.');
        $this->assertStringContainsString('boş', $onizleme['satirlar'][0]['aciklama']);
        $this->assertStringContainsString('kısa', $onizleme['satirlar'][1]['aciklama']);
        $this->assertStringContainsString('okunamadı', $onizleme['satirlar'][2]['aciklama']);
        $this->assertStringContainsString('Telefon yok', $onizleme['satirlar'][3]['aciklama'],
            'Telefonsuz satır eklenir ama tekrar riski söylenmeli.');
    }

    #[Test]
    public function baslik_satiri_olmayan_dosya_da_okunur(): void
    {
        $a = $this->makeTenant('a');

        $onizleme = $this->import()->onizleme($a['tenant']->id, "Ayşe Yılmaz;0532 111 22 33;;;\n");

        $this->assertSame(1, $onizleme['ozet']['eklenecek']);
        $this->assertSame(1, $onizleme['satirlar'][0]['satir'], 'Başlıksız dosyada ilk satır 1 numaralıdır.');
    }

    #[Test]
    public function virgullu_ayirac_ve_windows1254_kodlama_okunur(): void
    {
        $a = $this->makeTenant('a');

        // TR Excel "ANSI" kaydı: Windows-1254.
        $icerik = mb_convert_encoding("ad,telefon\nŞükrü Öztürk,0532 111 22 33\n", 'Windows-1254', 'UTF-8');

        $onizleme = $this->import()->onizleme($a['tenant']->id, $icerik);

        $this->assertSame(1, $onizleme['ozet']['eklenecek']);
        $this->assertSame('Şükrü Öztürk', $onizleme['satirlar'][0]['ad'], 'Türkçe karakterler bozulmamalı.');
    }

    #[Test]
    public function cok_buyuk_dosya_reddedilir(): void
    {
        $a = $this->makeTenant('a');
        $satirlar = [];
        for ($i = 0; $i < PanelImportService::MAX_SATIR + 5; $i++) {
            $satirlar[] = 'Müşteri '.$i.';;;;';
        }

        $this->expectException(RuntimeException::class);
        $this->import()->onizleme($a['tenant']->id, $this->csv(...$satirlar));
    }

    // --- İçe aktarım: uygulama ----------------------------------------------------------

    #[Test]
    public function uygulama_musterileri_yazar_ve_senkron_deltasina_duser(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        $imlec = (int) $this->pushEvents($token, [$this->customerUpsert(['name' => 'Cihazdan'])])->json('current_seq');

        $sonuc = $this->import()->uygula($a['tenant']->id, $this->csv(
            'Ayşe Yılmaz;0532 111 22 33;Şirinyalı Mah.;Muratpaşa;',
            'Mehmet Demir;0533 999 88 77;Kükürtlü Mah.;Osmangazi;',
        ), $admin->id);

        $this->assertSame('applied', $sonuc['durum']);
        $this->assertSame(2, $sonuc['eklenen']);

        $adlar = Provisioning::asOwner(fn () => Customer::query()->pluck('name')->all());
        $this->assertContains('Ayşe Yılmaz', $adlar);
        $this->assertContains('Mehmet Demir', $adlar);

        // Cihaza düştü mü?
        $degisiklikler = collect($this->pullSince($token, $imlec)->json('changes'));
        $aktarilanAdlar = $degisiklikler->where('entity_type', 'customer')->pluck('payload.name')->all();
        $this->assertContains('Ayşe Yılmaz', $aktarilanAdlar, 'Toplu aktarılan müşteri senkron deltasına düşmeli.');
        $this->assertContains('Mehmet Demir', $aktarilanAdlar);

        // Denetim: tek satır + adet (müşteri başına kayıt günlüğü boğardı).
        $denetim = DB::connection('pgsql_panel')->table('panel_audit')
            ->where('tenant_id', $a['tenant']->id)->where('action', 'customer_import')->first();
        $this->assertNotNull($denetim);
        $this->assertSame('n=2', $denetim->detail);
    }

    #[Test]
    public function ayni_dosyayi_ikinci_kez_aktarmak_cift_kayit_uretmez(): void
    {
        // Onboarding'de EN OLASI kullanıcı hatası budur: dosya bir kez daha yüklenir.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $dosya = $this->csv('Ayşe Yılmaz;0532 111 22 33;;;', 'Mehmet Demir;0533 999 88 77;;;');

        $this->assertSame(2, $this->import()->uygula($a['tenant']->id, $dosya, $admin->id)['eklenen']);

        $ikinci = $this->import()->uygula($a['tenant']->id, $dosya, $admin->id);

        $this->assertSame(0, $ikinci['eklenen'], 'İkinci aktarımda hiç müşteri eklenmemeli.');
        $this->assertSame(2, $ikinci['atlanan']);
        $this->assertSame(2, Provisioning::asOwner(fn () => Customer::query()->count()));
    }

    #[Test]
    public function kilitli_bayide_aktarim_hicbir_satir_yazmaz(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)
            ->update(['status' => 'locked', 'locked_at' => now()->subMinute(), 'valid_until' => now()->subDay()]));

        $sonuc = $this->import()->uygula($a['tenant']->id, $this->csv(
            'Ayşe Yılmaz;0532 111 22 33;;;',
            'Mehmet Demir;0533 999 88 77;;;',
        ), $admin->id);

        $this->assertSame('locked', $sonuc['durum']);
        $this->assertSame(0, $sonuc['eklenen']);
        $this->assertSame(0, Provisioning::asOwner(fn () => Customer::query()->count()),
            'Kısmi yazma KALMAMALI (transaction geri sarılır).');
    }

    #[Test]
    public function aktarim_baska_bayiye_sizmaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $admin = $this->makeAdmin();

        $this->import()->uygula($a['tenant']->id, $this->csv('A Müşterisi;0532 111 22 33;;;'), $admin->id);

        $bMusteriler = Provisioning::asOwner(fn () => Customer::query()->where('tenant_id', $b['tenant']->id)->count());
        $this->assertSame(0, $bMusteriler, 'B bayisine hiçbir şey yazılmamalı.');

        $aMusteri = Provisioning::asOwner(fn () => Customer::query()->where('tenant_id', $a['tenant']->id)->first());
        $this->assertSame('A Müşterisi', $aMusteri->name);
    }

    // --- CSV enjeksiyonu ----------------------------------------------------------------

    #[Test]
    public function tehlikeli_hucreler_kacirilir_sayilar_kacirilmaz(): void
    {
        $this->assertSame("'=HYPERLINK(\"http://kotu\")", Csv::hucre('=HYPERLINK("http://kotu")'));
        $this->assertSame("'+1234;cmd", Csv::hucre('+1234;cmd'));
        $this->assertSame("'@SUM(A1)", Csv::hucre('@SUM(A1)'));
        $this->assertSame("'-2+3+cmd|' /C calc'!A0", Csv::hucre('-2+3+cmd|\' /C calc\'!A0'));

        // Sayılar DOKUNULMADAN geçer — tırnaklanırsa dışa aktarım sayısal olarak işe yaramazdı.
        $this->assertSame('-1500', Csv::hucre('-1500'));
        $this->assertSame('-15,50', Csv::hucre('-15,50'));
        $this->assertSame('Ayşe Yılmaz', Csv::hucre('Ayşe Yılmaz'));
        $this->assertSame('', Csv::hucre(null));
    }

    #[Test]
    public function musteri_disa_aktariminda_formul_adi_kacirilir(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->yazici()->musteriKaydet($a['tenant']->id, [
            'ad' => '=cmd|calc', 'telefon' => '05321112233',
        ], $admin->id);

        $csv = $this->disa()->musteriler($a['tenant']->id);

        $this->assertStringContainsString("'=cmd|calc", $csv, 'Formül başlangıcı kaçırılmalı.');
        $this->assertStringNotContainsString(';=cmd|calc', $csv, 'Kaçırılmamış hâli dosyada OLMAMALI.');
    }

    // --- CSV dışa aktarımı --------------------------------------------------------------

    #[Test]
    public function musteri_csvsi_dolu_ve_cross_tenant_sizmaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $admin = $this->makeAdmin();

        $this->yazici()->musteriKaydet($a['tenant']->id, [
            'ad' => 'Ayşe Yılmaz', 'telefon' => '05321112233', 'adres' => 'Şirinyalı Mah.', 'bolge' => 'Muratpaşa',
        ], $admin->id);
        $this->yazici()->musteriKaydet($b['tenant']->id, ['ad' => 'B Müşterisi'], $admin->id);

        $csv = $this->disa()->musteriler($a['tenant']->id);

        $this->assertStringStartsWith("\xEF\xBB\xBF", $csv, 'BOM olmadan Excel Türkçe karakterleri bozar.');
        $this->assertStringContainsString('Ayşe Yılmaz', $csv);
        $this->assertStringContainsString('+905321112233', $csv);
        $this->assertStringContainsString('Şirinyalı Mah.', $csv);
        $this->assertStringContainsString('Muratpaşa', $csv);
        $this->assertStringNotContainsString('B Müşterisi', $csv, "B'nin müşterisi A'nın dosyasına SIZMAMALI.");
    }

    #[Test]
    public function siparis_csvsi_ekrandaki_suzgecin_aynisini_uygular(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $musteri = $this->customerUpsert(['name' => 'Ayşe Yılmaz']);
        $this->pushEvents($token, [$musteri])->assertOk();
        $siparis = $this->orderCreated([$this->line()], ['customer_id' => $musteri['payload']['id']]);
        $this->pushEvents($token, [$siparis])->assertOk();

        $hepsi = $this->disa()->siparisler($a['tenant']->id);
        $this->assertStringContainsString('Ayşe Yılmaz', $hepsi);

        $acik = $this->disa()->siparisler($a['tenant']->id, ['durum' => 'open']);
        $this->assertStringContainsString('Ayşe Yılmaz', $acik);

        $teslim = $this->disa()->siparisler($a['tenant']->id, ['durum' => 'delivered']);
        $this->assertStringNotContainsString('Ayşe Yılmaz', $teslim, 'Süzgeç dosyaya da uygulanmalı.');
    }

    #[Test]
    public function csv_indirme_yollari_oturum_ister_ve_dosya_dondurur(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        // Oturumsuz erişilemez.
        $this->get(route('panel.tenant.csv.musteriler', $a['tenant']->id))->assertRedirect(route('panel.login'));
        $this->get(route('panel.csv.sablon'))->assertRedirect(route('panel.login'));

        $this->actingAs($admin, 'admin');

        $this->get(route('panel.tenant.csv.musteriler', $a['tenant']->id))
            ->assertOk()
            ->assertHeader('Content-Type', 'text/csv; charset=utf-8')
            ->assertHeader('Content-Disposition', 'attachment; filename="musteriler-'.$a['tenant']->id.'.csv"');

        $this->get(route('panel.tenant.csv.siparisler', $a['tenant']->id))->assertOk();

        $sablon = $this->get(route('panel.csv.sablon'))->assertOk();
        $this->assertStringContainsString('ad;telefon;adres;bolge;not', $sablon->getContent());
    }

    // --- Ekran (Livewire) ---------------------------------------------------------------

    #[Test]
    public function ekranda_yukle_onizle_onayla_akisi_calisir(): void
    {
        Storage::fake('local');
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $this->actingAs($admin, 'admin');

        $dosya = UploadedFile::fake()->createWithContent('musteriler.csv', $this->csv(
            'Ayşe Yılmaz;0532 111 22 33;Şirinyalı Mah.;Muratpaşa;',
            'Ayşe Kopya;+90 532 111 2233;;;',      // dosya içi tekrar → atlanacak
            ';0555 000 00 00;;;',                  // hatalı → ad boş
        ));

        $bilesen = Livewire::test(CustomerImport::class, ['tenant' => $a['tenant']->id])
            ->set('dosya', $dosya)
            ->call('onizle')
            ->assertSee('Önizleme')
            ->assertSee('Eklenecek: 1')
            ->assertSee('Atlanacak: 1')
            ->assertSee('Hatalı: 1');

        // Önizleme hiçbir şey yazmadı.
        $this->assertSame(0, Provisioning::asOwner(fn () => Customer::query()->count()));

        $bilesen->call('uygula')
            ->assertSee('1 müşteri eklendi')
            ->assertSee('Hatalı satırlar');

        $this->assertSame(1, Provisioning::asOwner(fn () => Customer::query()->count()));
        $this->assertSame('Ayşe Yılmaz', Provisioning::asOwner(fn () => Customer::query()->first()->name));
    }

    #[Test]
    public function ekran_oturumsuz_acilmaz(): void
    {
        $a = $this->makeTenant('a');
        $this->get(route('panel.tenant.import', $a['tenant']->id))->assertRedirect(route('panel.login'));
    }
}
