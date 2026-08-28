<?php

namespace Tests\Feature\Api;

use App\Support\Cerez\CerezEnvanteri;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * ÇEREZ TERCİH MERKEZİ — KVKK AYDINLATMA YÜZEYİ (2026-08-28).
 *
 * ── BU DOSYA NEYİ KİLİTLİYOR ─────────────────────────────────────────────────────────────
 * `OlcumVeSeoTest` "rıza alınmadan Google'a istek gitmiyor" iddiasını kilitliyor — yani rızanın
 * SONUCUNU. Burada kilitlenen şey rızanın KENDİSİNİN geçerli olup olmadığı: KVK Kurulu'nun
 * çerez rehberi geçerli rıza için bilgilendirilmiş olmayı arar. Ziyaretçi hangi çerezin
 * yerleştirildiğini, ne kadar durduğunu ve kimin yerleştirdiğini GÖREBİLMELİ; reddi kabulden
 * zor olmamalı; verdiği kararın geri alınabilir olması gerekir.
 *
 * Bunlar "arayüz süsü" değil hukuki şartlardır ve sessizce kaybolabilirler: bir listeyi elle
 * güncellemeyi unutmak yeter. Testin ölçtüğü şey tam olarak bu unutmadır.
 *
 * ── ÖLÇÜLEMEYENİ ÖLÇÜYOR GİBİ YAPMIYOR ───────────────────────────────────────────────────
 * Anahtarların tıklandığında ne yaptığı, odak tuzağı ve Esc davranışı TARAYICI davranışıdır;
 * burada sınanmaz. Sunucu çıktısında sınanabilen şey, o davranışların dayandığı kancaların
 * (`data-cerez-kat`, `aria-controls`, düğme kimlikleri) var olmasıdır.
 */
class CerezYonetimiTest extends TestCase
{
    private function envanter(): CerezEnvanteri
    {
        return new CerezEnvanteri;
    }

    /** Ölçüm kapıları açıkken bir sayfa iste (üretim dışı ortamda varsayılan KAPALI). */
    private function sayfa(string $adres = '/'): string
    {
        config(['analitik.enabled' => true, 'analitik.measurement_id' => 'G-TEST00000']);

        return $this->get($adres)->assertOk()->getContent();
    }

    #[Test]
    public function pencere_bantla_birlikte_basilir_ve_tum_yollari_tasir(): void
    {
        $govde = $this->sayfa();

        /*
         * Bant: üç yol da tek tıklık — reddin ayarların arkasına saklanmaması rehberin şartı.
         * Pencere: kaydetme yolları + kapatma. Ayar kanalı: rıza mantığının yakıtı.
         *
         * ⚠️ HER KİMLİK TAM BİR KEZ. Bu "titizlik" değil, ÖLÇÜLMÜŞ BİR ARIZANIN bekçisi:
         * ilk yazımda bandın "Çerezleri yönet" düğmesi ile ayar JSON kanalı aynı `cerez-ayar`
         * kimliğini taşıyordu. `getElementById` belge sırasındaki İLKİNİ döndürür, yani betik
         * ayar diye bir düğmenin metnini okuyup `JSON.parse`ta düşüyor ve SESSİZCE hiç
         * kurulmuyordu — bant ve pencere ekranda duruyor, hiçbir düğme çalışmıyordu. Kimliklerin
         * varlığını tek tek doğrulayan bir test bunu göremez; ÇAKIŞMAMASI ölçülmeli.
         */
        $kimlikler = [
            'cerez-band', 'cerez-ret', 'cerez-yonet', 'cerez-kabul',
            'cerez-pencere', 'cerez-p-kapat', 'cerez-p-ret', 'cerez-p-kaydet', 'cerez-p-kabul',
            'cerez-ayar',
        ];

        foreach ($kimlikler as $kimlik) {
            $this->assertSame(
                1,
                mb_substr_count($govde, 'id="'.$kimlik.'"'),
                $kimlik.' kimliği ya sayfadan düşmüş ya da birden çok öğede — getElementById yanlış öğeyi döndürür.'
            );
        }

        $this->assertLessThan(
            (int) mb_strpos($govde, 'id="cerez-kabul"'),
            (int) mb_strpos($govde, 'id="cerez-ret"'),
            'Ret düğmesi kabulden önce gelmeli.'
        );

        $this->assertStringContainsString('role="dialog"', $govde);
        $this->assertStringContainsString('aria-modal="true"', $govde);
        $this->assertStringContainsString('js/cerez.js', $govde);
    }

    #[Test]
    public function pencere_hangi_cerezleri_topladigimizi_tek_tek_gosterir(): void
    {
        /*
         * AYDINLATMANIN KENDİSİ. Ziyaretçi "izin ver"e basarken neye izin verdiğini görmeli:
         * çerezin adı, ne işe yaradığı, ne kadar durduğu, kimin yerleştirdiği. Bu listeyi ayrı
         * bir sayfaya bırakmak, kararı veren kişinin onu okumadan karar vermesi demekti.
         *
         * Liste envanterden okunuyor: testin kendi kopyasını taşıması, ilk değişiklikte testin
         * de yanlış olması demek olurdu.
         */
        $govde = $this->sayfa();

        foreach ($this->envanter()->kategoriler() as $kategori) {
            $this->assertStringContainsString(e($kategori['ad']), $govde);

            foreach ($kategori['cerezler'] as $cerez) {
                $this->assertStringContainsString(
                    '<code>'.$cerez['ad'].'</code>',
                    $govde,
                    $cerez['ad'].' çerezi tercih penceresinde ilan edilmiyor.'
                );
                $this->assertStringContainsString($cerez['sure'], $govde);
                $this->assertStringContainsString(e($cerez['saglayici']), $govde);
            }
        }

        // GERÇEK oturum çerezinin adı — uydurma değil, Laravel'in kendi ayarından.
        $this->assertStringContainsString('<code>'.config('session.cookie').'</code>', $govde);

        // Çözülmemiş yer tutucu ekrana düşmemeli.
        $this->assertStringNotContainsString('%oturum_cerezi%', $govde);
        $this->assertStringNotContainsString('%riza_ay%', $govde);
    }

    #[Test]
    public function zorunlu_kategoride_anahtar_yok_secmelide_var(): void
    {
        /*
         * Kapatılamayan bir anahtar göstermek, ziyaretçiye olmayan bir seçim sunmaktır — ve
         * "kapattım sandım, kapanmamış" hissi güveni bir kerede bitirir. Zorunlu kategori
         * anahtar yerine "Her zaman açık" der ve gerekçesi (hukuki dayanak) yanında durur.
         */
        $govde = $this->sayfa();

        $this->assertStringContainsString('Her zaman açık', $govde);
        $this->assertStringContainsString('data-cerez-kat="olcum"', $govde);
        $this->assertStringNotContainsString('data-cerez-kat="zorunlu"', $govde);

        // Her kategori kendi hukuki dayanağını yanında taşır. `e()` şart: dayanak metninde
        // kesme işareti var ve Blade onu `&#039;` diye basar — ham dizeyle arama sessizce kırardı.
        foreach ($this->envanter()->kategoriler() as $kategori) {
            $this->assertStringContainsString(e($kategori['dayanak']), $govde);
        }
    }

    #[Test]
    public function karar_veren_ziyaretciye_bant_bir_daha_gosterilmez(): void
    {
        /*
         * ⚠️ `withUnencryptedCookie` BİLİNÇLİ ve testin can alıcı noktası.
         *
         * Rıza çerezini TARAYICIDAKİ JS yazar; Laravel'in imzasını taşımaz. `withCookie()`
         * kullanılsaydı test çerezi Laravel'in kendi şifrelemesiyle gönderirdi ve gerçek
         * tarayıcıda ÇALIŞMAYAN bir kod yeşil görünürdü — nitekim 2026-08-28'e kadar tam olarak
         * bu oldu: `EncryptCookies` çözemediği çerezi sessizce `null` yapıyor, sunucu kapısı
         * hiç işlemiyor, tercihini bildirmiş ziyaretçi her sayfada bandı bir an görüyordu.
         * Muafiyet bootstrap/app.php'de; bu test onun gerçekten yürürlükte olduğunu ölçer.
         */
        config(['analitik.enabled' => true, 'analitik.measurement_id' => 'G-TEST00000']);

        $govde = $this->withUnencryptedCookie(config('cerezler.cerez'), '1|olcum')
            ->get('/')->assertOk()->getContent();

        $this->assertMatchesRegularExpression(
            '/<div id="cerez-band"[^>]*\shidden/',
            $govde,
            'Tercihini bildirmiş ziyaretçiye bant yeniden gösteriliyor (çerez sunucuda okunamıyor olabilir).'
        );

        // Pencereye giden yol KAPANMAZ — rızanın geri alınabilir olması KVKK m.11 gereği.
        $this->assertStringContainsString('data-cerez-ac', $govde);
    }

    #[Test]
    public function liste_degisip_surum_artinca_karar_yeniden_sorulur(): void
    {
        config([
            'analitik.enabled' => true,
            'analitik.measurement_id' => 'G-TEST00000',
            'cerezler.surum' => 2,
        ]);

        $govde = $this->withUnencryptedCookie(config('cerezler.cerez'), '1|olcum')
            ->get('/')->assertOk()->getContent();

        $this->assertDoesNotMatchRegularExpression(
            '/<div id="cerez-band"[^>]*\shidden/',
            $govde,
            'Liste değiştiği hâlde eski rıza geçerli sayılıyor.'
        );
    }

    #[Test]
    public function politika_belgesi_pencereyle_ayni_listeyi_basar(): void
    {
        /*
         * İKİ LİSTE TUTMANIN BEDELİ ÖLÇÜLDÜ: belge `sipario_session` diyordu, gerçek ad
         * `sipario-session`di. Bu test, ikisinin tek kaynaktan geldiğini kilitler — belge ve
         * pencere aynı çerezleri, aynı sürelerle ilan etmek zorunda.
         */
        config(['analitik.enabled' => true, 'analitik.measurement_id' => 'G-TEST00000']);
        $belge = $this->get('/sozlesme/cerez-politikasi')->assertOk()->getContent();

        foreach ($this->envanter()->kategoriler() as $kategori) {
            foreach ($kategori['cerezler'] as $cerez) {
                $this->assertStringContainsString(
                    '<code>'.$cerez['ad'].'</code>',
                    $belge,
                    $cerez['ad'].' çerezi Çerez Politikası\'nda ilan edilmiyor.'
                );
                $this->assertStringContainsString($cerez['sure'], $belge);
            }
        }

        // Tercihin nerede saklandığı ve ne kadar durduğu belgede yazılı olmalı.
        $this->assertStringContainsString(config('cerezler.cerez'), $belge);
    }

    #[Test]
    public function olcum_kapaliyken_pencere_de_basilmaz(): void
    {
        /*
         * Rızaya bağlı hiçbir kategori yoksa sorulacak bir şey de yoktur. Bant ve pencere
         * basmak, cevabı olmayan bir soru sormak olurdu. Zorunlu çerezlerin bilgilendirmesi
         * Çerez Politikası'nda yapılır — orada ölçüm kapalıyken de görünürler.
         */
        config(['analitik.enabled' => false]);
        $govde = $this->get('/')->assertOk()->getContent();

        $this->assertStringNotContainsString('cerez-band', $govde);
        $this->assertStringNotContainsString('cerez-pencere', $govde);
        $this->assertStringNotContainsString('js/cerez.js', $govde);
        $this->assertStringNotContainsString('data-cerez-ac', $govde);

        $belge = $this->get('/sozlesme/cerez-politikasi')->assertOk()->getContent();
        $this->assertStringContainsString('<code>'.config('session.cookie').'</code>', $belge);
        $this->assertStringNotContainsString('<code>_ga</code>', $belge);
    }

    #[Test]
    public function pencere_gizliyken_gorunmez_kalir(): void
    {
        /*
         * ⚠️ BU TESTİ DOĞURAN ARIZA SAHADA GÖRÜLDÜ ve ilk sürümün en ağır kusuruydu.
         *
         * Pencere `hidden` özniteliğiyle basılıyor ama kabı `.diyalog-fon` bir SINIF seçicisiyle
         * `display:flex` alıyor. Tarayıcının `[hidden]{display:none}` kuralı kullanıcı ajanı
         * katmanındadır ve sınıf seçicisi onu ezer — yani pencere HER SAYFA AÇILIŞINDA tam ekran
         * açılıyordu. Kullanıcının "ekranı kaplıyor, rezalet" dediği şey buydu.
         *
         * Sunucu çıktısını okuyan testler bunu göremez (işaretleme doğruydu, `hidden` oradaydı)
         * ve jsdom da göremez (düzen/kaskad hesaplamaz). Görülebilen tek yer gerçek bir
         * tarayıcının hesaplanmış biçemidir; burada onun CSS tarafındaki KAYNAĞI kilitleniyor:
         * `hidden`i geri getiren kuralın dosyada bulunması. Kural silinirse bu test kırılır.
         */
        $css = (string) file_get_contents(public_path('css/site.css'));

        $this->assertMatchesRegularExpression(
            '/\.cerez-fon\[hidden\]\s*\{[^}]*display:\s*none/',
            $css,
            '.cerez-fon[hidden] kuralı silinmiş — `.diyalog-fon{display:flex}` `hidden`i eziyor '.
            've tercih penceresi her sayfa açılışında tam ekran açılır.'
        );

        // Pencere HTML'de gerçekten `hidden` basılmalı; kural tek başına yetmez.
        $govde = $this->sayfa();
        $this->assertMatchesRegularExpression('/<div id="cerez-pencere"[^>]*\shidden/', $govde);
    }

    #[Test]
    public function bant_metni_envanterle_tutarli_kalir(): void
    {
        /*
         * BANDIN METNİ TEK BİR KATEGORİYE GÖRE YAZILMIŞTIR: "ölçüm çerezi kullanmak istiyoruz",
         * düğme "Ölçüme izin ver". Bugün doğru — rızaya bağlı tek kategori ölçüm. İkinci bir
         * kategori eklendiği gün (gömülü video, kişiselleştirme, ne olursa) bu metin SESSİZCE
         * YALANA döner: düğme "ölçüme" derken aslında hepsini kabul eder ve ziyaretçi neye izin
         * verdiğini yanlış bilir — geçerli rızanın tam tersi.
         *
         * Bu test o günü GÖRÜNÜR yapar. Kırıldığında yapılacak şey testi gevşetmek değil,
         * cerez-onay.blade.php'deki bant metnini ve düğme etiketini kategorilerden bağımsız
         * hâle getirmektir (ör. "Tümünü kabul et").
         */
        config(['analitik.enabled' => true, 'analitik.measurement_id' => 'G-TEST00000']);

        $this->assertSame(
            ['olcum'],
            array_keys($this->envanter()->secmeliKategoriler()),
            'Rızaya bağlı kategori listesi değişmiş — bandın "Ölçüme izin ver" metni artık '.
            'kabul edilen her şeyi anlatmıyor. cerez-onay.blade.php metnini güncelle.'
        );
    }

    #[Test]
    public function riza_cerezi_sifrelemeden_muaf_tutulmus(): void
    {
        /*
         * Muafiyetin adı `bootstrap/app.php`de LİTERAL yazılıdır — o closure config yüklenmeden
         * önce koşar, `config()` orada çalışmaz. İki yerin sapması sessiz bir arıza üretir
         * (yukarıdaki bant testi kırmızıya döner ama sebebi orada görünmez), bu yüzden eşlik
         * burada açıkça ölçülür.
         */
        $kaynak = (string) file_get_contents(base_path('bootstrap/app.php'));

        $this->assertStringContainsString(
            "encryptCookies(except: ['".config('cerezler.cerez')."'])",
            $kaynak,
            'Rıza çerezinin adı bootstrap/app.php ile config/cerezler.php arasında sapmış.'
        );
    }
}
