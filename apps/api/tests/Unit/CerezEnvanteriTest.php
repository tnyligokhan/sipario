<?php

namespace Tests\Unit;

use App\Support\Cerez\CerezEnvanteri;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * ÇEREZ ENVANTERİ — RIZA DEĞERİNİN AYRIŞTIRILMASI (2026-08-28).
 *
 * ── NEDEN AYRI VE NEDEN UNIT ─────────────────────────────────────────────────────────────
 * `CerezYonetimiTest` arayüzün NE GÖSTERDİĞİNİ kilitliyor. Burada kilitlenen şey daha alttaki
 * sözleşme: bir çerez değerinin NE ANLAMA GELDİĞİ. Bu karar tek bir yerde verilir ve üç taraf
 * (bant, belge, ölçüm betiği) ona uyar; yanlış ayrıştırma "rıza vermemiş ziyaretçiyi ölçmek"
 * ya da tersi, "vermiş olanı her sayfada yeniden rahatsız etmek" demektir.
 *
 * HTTP'ye çıkmıyor: envanter saf bir okuyucudur, veritabanı istemez. Bunu feature testine
 * yıkmak, ayrıştırma hatasını sayfa gövdesinden okumaya çalışmak olurdu.
 */
class CerezEnvanteriTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Ölçüm kategorisi `kosul => analitik` taşır; kapalıyken envanterden düşer.
        config(['analitik.enabled' => true, 'analitik.measurement_id' => 'G-TEST00000']);
    }

    #[Test]
    public function karar_verilmemis_ziyaretci_ile_hepsini_reddeden_ziyaretci_ayrilir(): void
    {
        /*
         * Bu ayrım ürünün en kolay kaçırılan davranışı: ikisinde de ölçüm KAPALIDIR ama biri
         * "bana bir daha sorma" demiştir. Karıştırılırsa reddeden ziyaretçiye bant her sayfada
         * yeniden açılır — reddi cezalandıran bir tasarım, KVK Kurulu'nun rehberinin karşı
         * olduğu şeyin ta kendisidir.
         */
        $envanter = new CerezEnvanteri;

        $this->assertFalse($envanter->kararVerilmisMi(null), 'Çerezi olmayan ziyaretçi karar vermiş sayılıyor.');
        $this->assertTrue($envanter->kararVerilmisMi('1|'), 'Hepsini reddeden ziyaretçiye yeniden sorulacak.');
        $this->assertFalse($envanter->izinliMi('olcum', '1|'));
        $this->assertTrue($envanter->izinliMi('olcum', '1|olcum'));
    }

    #[Test]
    public function surum_degisince_eski_riza_gecersizlesir(): void
    {
        /*
         * Rıza, VERİLDİĞİ LİSTEYE aittir (KVKK m.3/1-a: belirli bir konuya ilişkin). Listeye
         * yeni bir çerez girdiğinde eski onay onu kapsamaz; sürüm artırılır ve bir kez daha
         * sorulur.
         */
        config(['cerezler.surum' => 2]);
        $envanter = new CerezEnvanteri;

        $this->assertFalse($envanter->kararVerilmisMi('1|olcum'), 'Eski sürümlü rıza hâlâ geçerli sayılıyor.');
        $this->assertFalse($envanter->izinliMi('olcum', '1|olcum'));
        $this->assertTrue($envanter->kararVerilmisMi('2|olcum'));
    }

    #[Test]
    public function eski_tek_dugmeli_bicim_onurlandirilir(): void
    {
        /*
         * 2026-08-19'daki ilk sürüm çerezi `kabul`/`ret` diye yazıyordu. O ziyaretçiler
         * kararlarını BUGÜNKÜYLE AYNI listeye vermişti; geçersiz saymak, hiçbir hukuki kazanç
         * sağlamadan herkese pencereyi yeniden açmak olurdu.
         */
        $envanter = new CerezEnvanteri;

        $this->assertTrue($envanter->izinliMi('olcum', 'kabul'));
        $this->assertTrue($envanter->kararVerilmisMi('ret'));
        $this->assertFalse($envanter->izinliMi('olcum', 'ret'));
    }

    #[Test]
    public function kurcalanmis_deger_bilinmeyen_kategori_acmaz(): void
    {
        // Çerez ziyaretçinin makinesindedir ve elle değiştirilebilir. Tanımadığımız bir kategori
        // adı, tanımlanmamış bir izne dönüşmemeli.
        $envanter = new CerezEnvanteri;

        $this->assertFalse($envanter->izinliMi('reklam', '1|reklam,olcum'));
        $this->assertTrue($envanter->izinliMi('olcum', '1|reklam,olcum'));
        $this->assertFalse($envanter->kararVerilmisMi('saçmalık'));
    }

    #[Test]
    public function zorunlu_kategori_her_zaman_aciktir_ve_secmelilerden_ayridir(): void
    {
        $envanter = new CerezEnvanteri;

        $this->assertTrue($envanter->izinliMi('zorunlu', null), 'Zorunlu çerezler rızaya bağlanmış.');
        $this->assertSame(['olcum'], array_keys($envanter->secmeliKategoriler()));
        $this->assertTrue($envanter->rizaGerekiyorMu());
    }

    #[Test]
    public function olcum_kapaliyken_sorulacak_bir_sey_kalmaz(): void
    {
        /*
         * Kategori koşulu sağlanmıyorsa envanterden DÜŞER: kurulmayan bir çerez için rıza
         * istemek, olmayan bir şeyi ilan etmektir. Zorunlu çerezler yine listelenir — Çerez
         * Politikası onları ölçüm kapalıyken de göstermek zorundadır.
         */
        config(['analitik.enabled' => false]);
        $envanter = new CerezEnvanteri;

        $this->assertFalse($envanter->rizaGerekiyorMu());
        $this->assertSame([], $envanter->secmeliKategoriler());
        $this->assertArrayHasKey('zorunlu', $envanter->kategoriler());
    }

    #[Test]
    public function cerez_adlari_gercek_kurulumdan_cozulur(): void
    {
        /*
         * BU TESTİN DOĞDUĞU HATA: belge `sipario_session` yazıyordu, tarayıcıya yazılan çerezin
         * gerçek adı `sipario-session`di. Ziyaretçi politikadaki adı tarayıcısında ARASA
         * BULAMAZDI. Yer tutucular gerçek yapılandırmadan çözülmezse aynı sapma geri gelir.
         */
        config(['session.cookie' => 'test-session', 'session.lifetime' => 45]);
        $zorunlu = (new CerezEnvanteri)->kategoriler()['zorunlu']['cerezler'];
        $adlar = array_column($zorunlu, 'ad');

        $this->assertContains('test-session', $adlar);
        $this->assertContains(config('cerezler.cerez'), $adlar);
        $this->assertSame('45 dakika', $zorunlu[0]['sure']);

        $olcum = (new CerezEnvanteri)->kategoriler()['olcum']['cerezler'];
        $this->assertContains('_ga_G-TEST00000', array_column($olcum, 'ad'));

        // Çözülmemiş bir yer tutucunun ekrana basılması, ziyaretçiye "%oturum_cerezi%" adlı bir
        // çerez olduğunu söylemek olurdu.
        foreach (array_merge($zorunlu, $olcum) as $cerez) {
            $this->assertStringNotContainsString('%', implode(' ', $cerez));
        }
    }

    #[Test]
    public function tarayici_ayari_betigin_ihtiyaci_olan_her_seyi_tasir(): void
    {
        // public/js/cerez.js bu dört alanı okur ve config'i başka bir yerden tahmin etmez.
        $ayar = (new CerezEnvanteri)->tarayiciAyari();

        $this->assertSame(config('cerezler.cerez'), $ayar['cerez']);
        $this->assertSame(config('cerezler.gun'), $ayar['gun']);
        $this->assertSame(config('cerezler.surum'), $ayar['surum']);
        $this->assertSame(['olcum'], $ayar['kategoriler']);
    }
}
