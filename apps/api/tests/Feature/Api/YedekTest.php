<?php

namespace Tests\Feature\Api;

use App\Mail\YedekHazir;
use App\Models\AdminUser;
use App\Support\Provisioning;
use App\Yedek\YedekArsivi;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * GÜNLÜK YEDEK BİLDİRİMİ (2026-08-15) — arşiv okuma, indirme kapısı ve postanın kendisi.
 *
 * NEDEN BU TESTLER VAR: yedek dosyası ürünün en yoğun kişisel veri taşıyıcısıdır (tüm bayilerin
 * tüm müşterileri tek dosyada) ve bu vardiyada ona İKİ yeni yol açıldı — bir HTTP route'u ve bir
 * e-posta. İkisi de yanlış kurulduğunda sessizdir: gevşek bir dosya-adı kontrolü hata vermez,
 * yalnız yanlış dosyayı verir; tanımsız bir alıcı adresi hata vermez, yalnız postayı hiçbir yere
 * göndermez. Buradaki testler o iki sessizliği sese çevirir.
 */
class YedekTest extends ApiTestCase
{
    private string $arsiv;

    protected function setUp(): void
    {
        parent::setUp();

        $this->arsiv = sys_get_temp_dir().'/sipario-yedek-test-'.bin2hex(random_bytes(6));

        foreach (['daily', 'weekly', 'monthly'] as $kova) {
            mkdir($this->arsiv.'/'.$kova, 0o777, true);
        }

        config([
            'yedek.dizin' => $this->arsiv,
            'yedek.eposta' => 'patron@sipario.test',
            'yedek.tazelik_saat' => 30,
        ]);
    }

    protected function tearDown(): void
    {
        foreach (['daily', 'weekly', 'monthly'] as $kova) {
            foreach ((array) glob($this->arsiv.'/'.$kova.'/*') as $dosya) {
                if (is_string($dosya)) {
                    unlink($dosya);
                }
            }
            @rmdir($this->arsiv.'/'.$kova);
        }
        @rmdir($this->arsiv);

        parent::tearDown();
    }

    private function yedekYaz(string $ad, string $kova = 'daily', string $icerik = 'yedek-verisi'): string
    {
        $yol = $this->arsiv.'/'.$kova.'/'.$ad;
        file_put_contents($yol, gzencode($icerik));

        return $yol;
    }

    /** Şu ana yakın (taze) bir yedek adı — damga UTC'dir, sidecar `date` çıktısıyla aynı. */
    private function tazeAd(): string
    {
        return 'sipario_'.gmdate('Ymd_His').'.sql.gz';
    }

    private function admin(string $rol = 'superadmin', string $email = 'yedek-super@sipario.test'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Yedek Testi', 'email' => $email, 'password' => 'panel-secret', 'role' => $rol,
        ]));
    }

    // ── Arşiv okuma ───────────────────────────────────────────────────────────────────

    #[Test]
    public function coz_arsiv_disina_cikan_adi_reddeder(): void
    {
        // Bu testin varlık sebebi tek bir cümle: dosya adı KULLANICIDAN geliyor. Route
        // `{dosya}` parametresini doğrudan bu metoda veriyor; burada bir delik açılırsa
        // panele giren biri container'ın herhangi bir dosyasını indirebilir.
        $arsiv = new YedekArsivi($this->arsiv);

        // Gerçekten var olan, ama arşivin DIŞINDAKİ bir dosyayı hedefle — reddin sebebi
        // "dosya yok" olmasın, kapının kendisi olsun.
        $disarida = sys_get_temp_dir().'/sipario-sizinti-'.bin2hex(random_bytes(4)).'.txt';
        file_put_contents($disarida, 'gizli');

        $denemeler = [
            '../'.basename($disarida),
            '../../etc/passwd',
            '/etc/passwd',
            'daily/../../'.basename($disarida),
            '..\\..\\windows\\win.ini',
        ];

        foreach ($denemeler as $deneme) {
            $this->assertNull($arsiv->coz($deneme), "Arşiv dışına çıkan ad reddedilmeli: {$deneme}");
        }

        unlink($disarida);
    }

    #[Test]
    public function coz_yalniz_sidecarin_urettigi_ad_desenini_kabul_eder(): void
    {
        // Desen, "dizine elle atılmış bir dosya indirilebilir olmasın" kapısıdır. `.env.gz`
        // ya da `notlar.sql.gz` arşive düşerse (yanlış bir kopyalama, bir hata ayıklama
        // kalıntısı) indirilebilir OLMAMALI.
        $arsiv = new YedekArsivi($this->arsiv);

        foreach (['notlar.sql.gz', 'sipario_2026_03.sql.gz', 'sipario_20260815_030000.sql', 'sipario_20260815_030000.sql.gz.bak'] as $ad) {
            $this->yedekYaz($ad);
            $this->assertNull($arsiv->coz($ad), "Desene uymayan ad reddedilmeli: {$ad}");
        }

        $gecerli = $this->tazeAd();
        $this->yedekYaz($gecerli);
        $this->assertNotNull($arsiv->coz($gecerli), 'Sidecar biçimindeki ad kabul edilmeli.');
    }

    #[Test]
    public function son_yedek_ada_gore_secilir_dosya_zamanina_gore_degil(): void
    {
        // Sıralama `filemtime` ile yapılsaydı bu test kırılırdı: aşağıda ESKİ yedek SONRA
        // yazılıyor (haftalık kovaya kopyalanan bir dosyanın mtime'ı tazelenir, tıpkı
        // backup.sh:64'teki `cp` gibi). Ad sıralaması bu tuzağa düşmez.
        $yeni = 'sipario_20260815_030000.sql.gz';
        $eski = 'sipario_20260101_030000.sql.gz';

        $this->yedekYaz($yeni);
        $this->yedekYaz($eski, 'weekly');
        touch($this->arsiv.'/weekly/'.$eski, time() + 600);

        $son = (new YedekArsivi($this->arsiv))->sonYedek();

        $this->assertNotNull($son);
        $this->assertSame($yeni, $son['ad'], 'En yeni yedek ADA göre seçilmeli.');
    }

    #[Test]
    public function ayni_yedek_iki_kovada_duruyorsa_bir_kez_sayilir(): void
    {
        // backup.sh Pazar günü aynı dosyayı `weekly`e KOPYALAR. Tekilleştirme olmasaydı
        // arşiv listesi o günlerde çift kayıt gösterirdi.
        $ad = 'sipario_20260802_030000.sql.gz';
        $this->yedekYaz($ad);
        $this->yedekYaz($ad, 'weekly');

        $this->assertSame([$ad], (new YedekArsivi($this->arsiv))->adlar());
    }

    // ── Komut ─────────────────────────────────────────────────────────────────────────

    #[Test]
    public function komut_alici_adresi_tanimsizsa_hata_ile_cikar(): void
    {
        // ⚠️ BU TESTİN ASIL KONUSU SESSİZLİK. Adres tanımsızken komut BAŞARIYLA dönerse,
        // zamanlayıcı her sabah "yeşil" der ve yedek bildirimi aylarca hiç gitmez —
        // parola sıfırlama postasının başına gelen tam olarak buydu.
        Mail::fake();
        config(['yedek.eposta' => '']);
        $this->yedekYaz($this->tazeAd());

        $this->assertSame(1, Artisan::call('yedek:baglanti-gonder'));
        // İkisi birden: postalar kuyruğa girdiği için tek başına `assertNothingSent`
        // her hâlükârda geçerdi ve hiçbir şey kanıtlamazdı.
        Mail::assertNothingQueued();
        Mail::assertNothingSent();
    }

    #[Test]
    public function komut_arsiv_bossa_hata_ile_cikar(): void
    {
        // Yedek yoksa sorun e-postada değil, YEDEKLEMEDEdir. Komutun sessizce başarılı
        // dönmesi, sidecar'ın durduğunu görünmez kılardı.
        Mail::fake();

        $this->assertSame(1, Artisan::call('yedek:baglanti-gonder'));
        // İkisi birden: postalar kuyruğa girdiği için tek başına `assertNothingSent`
        // her hâlükârda geçerdi ve hiçbir şey kanıtlamazdı.
        Mail::assertNothingQueued();
        Mail::assertNothingSent();
    }

    #[Test]
    public function komut_taze_yedegin_baglantisini_postalar(): void
    {
        Mail::fake();
        $ad = $this->tazeAd();
        $this->yedekYaz($ad);

        $this->assertSame(0, Artisan::call('yedek:baglanti-gonder'));

        // `assertQueued`, `assertSent` DEĞİL: `SiparioPostasi` ShouldQueue'dur ve bu depoda
        // her posta kuyruğa girer (SMTP el sıkışması isteği bekletmesin diye). `assertSent`
        // burada HER ZAMAN başarısız olurdu — kuyruğa alınan posta "gönderilmiş" sayılmaz.
        Mail::assertQueued(YedekHazir::class, function (YedekHazir $posta) use ($ad) {
            $this->assertFalse($posta->bayat, 'Taze yedek bayat işaretlenmemeli.');
            $this->assertSame(route('panel.yedek.indir', ['dosya' => $ad]), $posta->indirmeUrl);
            $this->assertSame($ad, $posta->satirlar['Dosya']);
            $this->assertStringContainsString($ad, $posta->geriYuklemeKomutu);

            // Geri yükleme komutu ORTAMDAN okunmalı, koda elle yazılmamalı (PLAN 15. madde).
            $this->assertStringContainsString((string) config('yedek.geri_yukleme_rolu'), $posta->geriYuklemeKomutu);
            $this->assertStringContainsString((string) config('yedek.veritabani'), $posta->geriYuklemeKomutu);

            return $posta->hasTo('patron@sipario.test');
        });
    }

    #[Test]
    public function komut_bayat_yedegi_uyari_ile_postalar(): void
    {
        // Sidecar durduğunda yedek dosyası KAYBOLMAZ, sadece TAZELENMEZ. Uyarı bandı
        // olmasaydı her sabah "yedek geldi" diye bakıp aylarca aynı eski dosyayı
        // indirmek mümkün olurdu — yedeği olduğunu sanmanın en pahalı biçimi.
        Mail::fake();
        $this->yedekYaz('sipario_20260101_030000.sql.gz');

        $this->assertSame(0, Artisan::call('yedek:baglanti-gonder'));

        // `assertQueued`, `assertSent` DEĞİL: `SiparioPostasi` ShouldQueue'dur ve bu depoda
        // her posta kuyruğa girer (SMTP el sıkışması isteği bekletmesin diye). `assertSent`
        // burada HER ZAMAN başarısız olurdu — kuyruğa alınan posta "gönderilmiş" sayılmaz.
        Mail::assertQueued(YedekHazir::class, function (YedekHazir $posta) {
            $this->assertTrue($posta->bayat, 'Eski yedek bayat işaretlenmeli.');
            $this->assertNotSame('', $posta->bayatUyarisi);

            return true;
        });
    }

    #[Test]
    public function postanin_html_ve_duz_metin_karsiligi_uretilebiliyor(): void
    {
        // SiparioPostasi her posta için iki görünüm çözer; `eposta/metin/yedek-hazir`
        // dosyası unutulsaydı gönderim ÇALIŞMA ANINDA patlardı — yani bu kusur ancak
        // canlıda, ilk gönderimde görünürdü.
        $this->yedekYaz($this->tazeAd());
        $son = (new YedekArsivi($this->arsiv))->sonYedek();
        $this->assertNotNull($son);

        $posta = new YedekHazir(
            indirmeUrl: 'https://ornek.test/panel/yedek/'.$son['ad'],
            satirlar: ['Dosya' => $son['ad'], 'Boyut' => '2,1 MB'],
            geriYuklemeKomutu: 'gunzip -c '.$son['ad'].' | docker compose exec -T db psql',
            tarihEtiketi: '15 Ağustos 2026',
            bayat: true,
            bayatUyarisi: 'Bu yedek 40 saat önce alınmış.',
        );

        $render = $posta->render();
        $this->assertStringContainsString($son['ad'], $render);
        $this->assertStringContainsString('40 saat önce', $render, 'Bayat uyarısı HTML gövdede görünmeli.');
    }

    // ── İndirme kapısı ────────────────────────────────────────────────────────────────

    #[Test]
    public function yedegi_yalniz_superadmin_indirebilir(): void
    {
        // `auth:admin` yalnız "giriş yapmış mı" sorusunu cevaplar. `support` rolü bayi
        // destekler — TÜM bayilerin veritabanını taşımaz. Kapı route'un içindedir.
        $ad = $this->tazeAd();
        $this->yedekYaz($ad);

        $this->actingAs($this->admin('support', 'yedek-destek@sipario.test'), 'admin');
        $this->get(route('panel.yedek.indir', ['dosya' => $ad]))->assertForbidden();

        $this->actingAs($this->admin(), 'admin');
        $this->get(route('panel.yedek.indir', ['dosya' => $ad]))
            ->assertOk()
            ->assertDownload($ad);
    }

    #[Test]
    public function indirme_route_u_arsiv_disina_cikamaz(): void
    {
        // `coz()` testi sınıf düzeyinde aynı kapıyı ölçüyor; bu test o kapının ROUTE'a
        // gerçekten bağlı olduğunu gösterir. İkisi ayrı sorulardır: koruma var olabilir
        // ama çağrılmıyor olabilir.
        $this->actingAs($this->admin(), 'admin');

        foreach (['../../etc/passwd', 'sipario_20260815_030000.sql.gz', 'notlar.sql.gz'] as $ad) {
            $this->get(route('panel.yedek.indir', ['dosya' => $ad]))->assertNotFound();
        }
    }

    #[Test]
    public function her_indirme_denetim_gunlugune_dusuyor(): void
    {
        // Panelin en yüksek riskli veri çıkışı izsiz kalamaz: "veriyi kim ne zaman aldı"
        // sorusunun cevabı burada üretilir. Detaya YALNIZ dosya adı yazılır — panel_audit'in
        // KVKK-nötr sözleşmesi gereği içeriğe dair hiçbir şey girmez.
        $ad = $this->tazeAd();
        $this->yedekYaz($ad);
        $super = $this->admin();

        $this->actingAs($super, 'admin');
        $this->get(route('panel.yedek.indir', ['dosya' => $ad]))->assertOk();

        $kayit = DB::connection('pgsql_owner')->table('panel_audit')
            ->where('action', 'yedek_indirme')->first();

        $this->assertNotNull($kayit, 'Yedek indirme denetim günlüğüne düşmeli.');
        $this->assertSame($super->id, $kayit->admin_user_id);
        $this->assertSame($ad, $kayit->detail);
        $this->assertNull($kayit->tenant_id, 'Yedek tüm bayileri kapsar — tek bir bayiye işaret etmemeli.');
    }
}
