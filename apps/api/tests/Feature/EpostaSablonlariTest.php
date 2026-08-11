<?php

namespace Tests\Feature;

use App\Mail\DenemeBitiyor;
use App\Mail\EkPaketTanimlandi;
use App\Mail\HavaleTalimati;
use App\Mail\Hosgeldiniz;
use App\Mail\IcBildirim;
use App\Mail\KuryeHesabiAcildi;
use App\Mail\OdemeBeyaniAlindi;
use App\Mail\OdemeEslesmedi;
use App\Mail\OdemeOnaylandi;
use App\Mail\ParolaDegisti;
use App\Mail\ParolaSifirlama;
use App\Mail\SiparioPostasi;
use App\Mail\SureDoldu;
use App\Mail\YenilemeHatirlatmasi;
use App\Models\AddonPackage;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use Symfony\Component\Mime\Email;
use Tests\TestCase;

/**
 * E-POSTA ŞABLONLARININ SÖZLEŞMESİ.
 *
 * Bu testin işi "posta güzel mi" değil — güzelliği makine ölçemez. İşi, tasarımı AYAKTA TUTAN
 * KISITLARIN sessizce delinmesini engellemek. Her iddia, delindiğinde ürünü bozan ama hiçbir
 * ekranda kırmızı yanmayan bir davranışa karşılık gelir:
 *
 *  - `<svg>` / `<img>` YOK        → Gmail SVG'yi siler, uzak görsel "resimleri göster" denene
 *                                    kadar boş kutudur; markanın ilk izlenimi kırık ikon olur.
 *  - `display:flex|grid` YOK      → Outlook'un Word çizicisi ikisini de tanımaz, yerleşim çöker.
 *  - Çözülmemiş bileşen YOK       → `<x-eposta...>` çıktıda kalırsa Blade adı bulamamıştır ve
 *                                    posta ham etiketle gider.
 *  - Yer tutucu künye SIZMAZ      → config bugün "[Şirket IBAN]" taşıyor; müşteriye gitmemeli.
 *  - Düz metin karşılığı VAR      → `text` görünümü yoksa render patlar; bu test onu her
 *                                    şablon için zorlar (spam puanı + erişilebilirlik).
 *  - Konu satırı Türkçe ve dolu   → İngilizce'ye düşen Laravel varsayılanı bu ürünün yaşadığı
 *                                    gerçek arızaydı (lang/tr yok).
 */
class EpostaSablonlariTest extends TestCase
{
    /**
     * Her şablon en az bir kez, gerçekçi verilerle.
     *
     * @return array<string, array{0: SiparioPostasi}>
     */
    public static function sablonlar(): array
    {
        return [
            'hosgeldiniz' => [new Hosgeldiniz(
                isletme: 'Merkez Su Bayii', yetkili: 'Mehmet Yılmaz', firmaKodu: 'merkezsu',
                kullaniciAdi: 'patron', denemeBitisi: '11 Eylül 2026', denemeGun: 30,
                hesapUrl: 'https://sipario.com.tr/hesap',
            )],
            'havale-talimati' => [new HavaleTalimati(
                unvan: 'Sipario Yazılım A.Ş.', banka: 'Ziraat Bankası',
                iban: 'TR12 0001 0000 0000 0000 0000 01', tutarKurus: 598800,
                referans: 'MERKEZSU-4F2A',
            )],
            'odeme-beyani-alindi' => [new OdemeBeyaniAlindi(
                isletme: 'Merkez Su Bayii', tutarKurus: 598800, referans: 'MERKEZSU-4F2A',
                yontem: 'iban', beyanTarihi: '12 Ağustos 2026',
            )],
            'odeme-onaylandi' => [new OdemeOnaylandi(
                isletme: 'Merkez Su Bayii', tutarKurus: 598800, donem: 'Yıllık',
                gecerlilikBitisi: '12 Ağustos 2027', hesapUrl: 'https://sipario.com.tr/hesap',
            )],
            'odeme-eslesmedi' => [new OdemeEslesmedi(
                isletme: 'Merkez Su Bayii', tutarKurus: 598800, referans: 'MERKEZSU-4F2A',
                beyanTarihi: '12 Ağustos 2026', abonelikUrl: 'https://sipario.com.tr/abonelik',
                not: 'Hesabımıza bu tutarda bir giriş görünmedi.',
            )],
            'kurye-hesabi-acildi' => [new KuryeHesabiAcildi(
                isletme: 'Merkez Su Bayii', kuryeAdi: 'Ali Demir', kullaniciAdi: 'ali',
                firmaKodu: 'merkezsu', kalanHak: 2, hesapUrl: 'https://sipario.com.tr/hesap',
            )],
            'kurye-hesabi-acildi-hak-doldu' => [new KuryeHesabiAcildi(
                isletme: 'Merkez Su Bayii', kuryeAdi: 'Ali Demir', kullaniciAdi: 'ali',
                firmaKodu: 'merkezsu', kalanHak: 0, hesapUrl: 'https://sipario.com.tr/hesap',
            )],
            'parola-degisti' => [new ParolaDegisti(
                yetkili: 'Mehmet Yılmaz', zaman: '12 Ağustos 2026, 14:32',
            )],
            'parola-sifirlama' => [new ParolaSifirlama(
                yetkili: 'Mehmet Yılmaz', url: 'https://sipario.com.tr/parola/yenile/abc123?email=a%40b.c',
                gecerlilikDakika: 60,
            )],
            'ek-paket-kurye' => [new EkPaketTanimlandi(
                isletme: 'Merkez Su Bayii', paketAdi: '2 Kurye Paketi',
                tur: AddonPackage::TYPE_COURIER, adet: 2, tutarKurus: 120000,
                tanimlamaTarihi: '12 Ağustos 2026', hesapUrl: 'https://sipario.com.tr/hesap',
            )],
            'ek-paket-bedelsiz' => [new EkPaketTanimlandi(
                isletme: 'Merkez Su Bayii', paketAdi: '100 Rota Kontörü',
                tur: AddonPackage::TYPE_CREDITS, adet: 100, tutarKurus: 0,
                tanimlamaTarihi: '12 Ağustos 2026', hesapUrl: 'https://sipario.com.tr/hesap',
            )],
            'deneme-bitiyor-7' => [new DenemeBitiyor(
                isletme: 'Merkez Su Bayii', yetkili: 'Mehmet Yılmaz', kalanGun: 7,
                bitisTarihi: '19 Ağustos 2026', abonelikUrl: 'https://sipario.com.tr/abonelik',
                yillikTutar: '5.988 ₺',
            )],
            'deneme-bitiyor-1' => [new DenemeBitiyor(
                isletme: 'Merkez Su Bayii', yetkili: 'Mehmet Yılmaz', kalanGun: 1,
                bitisTarihi: '13 Ağustos 2026', abonelikUrl: 'https://sipario.com.tr/abonelik',
            )],
            'yenileme-hatirlatmasi' => [new YenilemeHatirlatmasi(
                isletme: 'Merkez Su Bayii', yetkili: 'Mehmet Yılmaz', kalanGun: 15,
                bitisTarihi: '27 Ağustos 2026', abonelikUrl: 'https://sipario.com.tr/abonelik',
                yillikTutar: '5.988 ₺',
            )],
            'sure-doldu-deneme' => [new SureDoldu(
                isletme: 'Merkez Su Bayii', yetkili: 'Mehmet Yılmaz',
                bitisTarihi: '11 Ağustos 2026', abonelikUrl: 'https://sipario.com.tr/abonelik',
                denemeydi: true,
            )],
            'sure-doldu-abonelik' => [new SureDoldu(
                isletme: 'Merkez Su Bayii', yetkili: 'Mehmet Yılmaz',
                bitisTarihi: '11 Ağustos 2026', abonelikUrl: 'https://sipario.com.tr/abonelik',
                denemeydi: false,
            )],
            'ic-bildirim' => [new IcBildirim(
                baslik: 'Veri dışa aktarma talebi', konuEki: 'dışa aktarma talebi · merkezsu',
                satirlar: ['Bayi' => 'Merkez Su Bayii', 'Firma kodu' => 'merkezsu'],
                aciklama: 'Bayi hesap sayfasından dışa aktarım istedi.',
            )],
        ];
    }

    /**
     * Postayı GERÇEKTEN gönderip üretilen iletiyi döndürür.
     *
     * `render()` yalnız HTML'i verir; düz metin gövdesi ancak ileti kurulduğunda oluşur. Gerçek
     * gönderim yolundan geçmenin iki bedava kazancı daha var: (1) `ShouldQueue` olduğumuz için
     * ileti kuyruğa serileştirilip geri açılır — yani şablonların kuyruk-güvenli olduğu
     * (yalnız skaler/dizi taşıdıkları) burada kanıtlanır; (2) zarf ayarları (konu, yanıt adresi)
     * kâğıt üstünde değil, üretilen iletide doğrulanır. Test ortamında `MAIL_MAILER=array` ve
     * `QUEUE_CONNECTION=sync` (phpunit.xml), yani ileti anında dizi taşıyıcıya düşer.
     */
    private function ileti(SiparioPostasi $posta): Email
    {
        Mail::to('bayi@ornek.test')->send($posta);

        /** @var Email $mesaj */
        $mesaj = Mail::getSymfonyTransport()->messages()->last()->getOriginalMessage();

        return $mesaj;
    }

    #[Test]
    #[DataProvider('sablonlar')]
    public function html_govdesi_derlenir_ve_bilesenler_cozulur(SiparioPostasi $posta): void
    {
        $html = (string) $this->ileti($posta)->getHtmlBody();

        $this->assertNotSame('', trim($html), 'HTML gövde boş üretildi.');

        // Çözülmemiş bileşen: Blade adı bulamamışsa etiket çıktıda ham kalır ve posta bozuk gider.
        $this->assertStringNotContainsString('<x-eposta', $html, 'Çözülmemiş Blade bileşeni kaldı.');

        // Markanın posta kutusundaki iki taşıyıcısı: wordmark ve hizmet bildirimi beyanı.
        $this->assertStringContainsString('Sipario', $html);
        $this->assertStringContainsString('hizmet bildirimidir', $html);
    }

    #[Test]
    #[DataProvider('sablonlar')]
    public function duz_metin_karsiligi_vardir(SiparioPostasi $posta): void
    {
        // `text` görünümü eksikse ileti kurulurken InvalidArgumentException atılır — yani bu
        // iddia, düz metin dosyasını yazmayı unutmayı imkânsız kılar.
        $metin = (string) $this->ileti($posta)->getTextBody();

        $this->assertNotSame('', trim($metin), 'Düz metin gövde boş üretildi.');
        $this->assertStringNotContainsString('<', $metin, 'Düz metin sürümüne HTML sızmış.');
    }

    #[Test]
    #[DataProvider('sablonlar')]
    public function posta_istemcisi_kisitlarina_uyar(SiparioPostasi $posta): void
    {
        $html = (string) $this->ileti($posta)->getHtmlBody();

        // Gmail `<svg>`i tamamen siler; uzak `<img>` "resimleri göster" denene kadar boş kutudur.
        $this->assertStringNotContainsString('<svg', $html, 'SVG kullanılmış — Gmail siler.');
        $this->assertStringNotContainsString('<img', $html, 'Görsel kullanılmış — engellenirse marka kırık görünür.');

        // Outlook'un Word çizicisi flex/grid tanımaz; yerleşim tabloyla kurulur.
        $this->assertStringNotContainsString('display:flex', $html, 'flex kullanılmış — Outlook tanımaz.');
        $this->assertStringNotContainsString('display:grid', $html, 'grid kullanılmış — Outlook tanımaz.');
    }

    #[Test]
    #[DataProvider('sablonlar')]
    public function konu_satiri_doludur_ve_musteriye_giden_postada_marka_on_eki_yoktur(SiparioPostasi $posta): void
    {
        $konu = (string) $this->ileti($posta)->getSubject();

        $this->assertNotSame('', trim($konu), 'Konu satırı boş.');

        // "Sipario ·" ön eki YALNIZ iç bildirimlerde meşrudur (süzgeç anahtarı). Müşteriye giden
        // postada gönderen adı zaten Sipario'dur; ön ek, telefonda kırpılan konu satırında yer yer.
        if (! $posta instanceof IcBildirim) {
            $this->assertStringNotContainsString('Sipario ·', (string) $konu);
        }
    }

    #[Test]
    #[DataProvider('sablonlar')]
    public function yer_tutucu_kunye_musteriye_sizmaz(SiparioPostasi $posta): void
    {
        // config/subscription.php bugün "[Şirket adresi]" gibi köşeli parantezli değerler taşıyor
        // ve bunu bilerek yapıyor. Düzen bileşeni onları süzer; süzgeç kalkarsa burası kırmızı yanar.
        $ileti = $this->ileti($posta);

        $this->assertStringNotContainsString('[Şirket', (string) $ileti->getHtmlBody());
        $this->assertStringNotContainsString('[Şirket', (string) $ileti->getTextBody());
    }

    #[Test]
    public function para_bicimi_sitedeki_tl_ile_ayni(): void
    {
        // Postada "5.988 ₺", ekranda "5.988,00 ₺" görmek bayide "hangisi doğru" sorusunu doğurur.
        $html = (new HavaleTalimati(
            unvan: 'X', banka: 'Y', iban: 'TR1', tutarKurus: 598800, referans: 'R',
        ))->render();

        $this->assertStringContainsString('5.988 ₺', $html);
    }

    #[Test]
    public function kurye_postasinda_parola_yer_almaz(): void
    {
        // Kurye parolası patronun belirlediği paroladır; postaya kopyalamak posta kutusunu ele
        // geçiren herkese hazır bir hesap vermek olurdu.
        $posta = new KuryeHesabiAcildi(
            isletme: 'Merkez Su Bayii', kuryeAdi: 'Ali Demir', kullaniciAdi: 'ali',
            firmaKodu: 'merkezsu', kalanHak: 1, hesapUrl: 'https://sipario.com.tr/hesap',
        );

        $this->assertStringContainsString('Parola bu iletide yok', $posta->render());
        $this->assertStringContainsString('ali', $posta->render());
    }

    #[Test]
    public function sure_doldu_postasi_veri_guvencesini_odeme_cagrisindan_once_soyler(): void
    {
        // BRIEF kırmızı çizgi #5. Bayi bu postayı kilidi gördüğü gün okur; ilk cümlesi "defterim
        // ne oldu" sorusuna cevap vermezse ürüne güven ölür.
        $html = (new SureDoldu(
            isletme: 'Merkez Su Bayii', yetkili: 'Mehmet', bitisTarihi: '11 Ağustos 2026',
            abonelikUrl: 'https://sipario.com.tr/abonelik',
        ))->render();

        $guvence = mb_strpos($html, 'Verileriniz duruyor');
        $cagri = mb_strpos($html, 'Aboneliği başlat');

        $this->assertNotFalse($guvence, 'Veri güvencesi cümlesi yok.');
        $this->assertNotFalse($cagri, 'Ödeme çağrısı yok.');
        $this->assertLessThan($cagri, $guvence, 'Ödeme çağrısı veri güvencesinden önce geliyor.');
    }

    #[Test]
    public function parola_degisti_postasinda_tiklanacak_baglanti_yoktur(): void
    {
        // "Değiştirmediyseniz tıklayın" kalıbı kimlik avının birebir taklit ettiği kalıptır;
        // bayiyi ona alıştırmak yarın sahtesini tıklamasını kolaylaştırır.
        $html = (new ParolaDegisti(yetkili: 'Mehmet', zaman: '12 Ağustos 2026, 14:32'))->render();

        // Alt bilgideki `mailto:` destek adresi dışında hiçbir bağlantı olmamalı.
        preg_match_all('/href="([^"]+)"/', $html, $eslesmeler);
        foreach ($eslesmeler[1] as $adres) {
            $this->assertStringStartsWith('mailto:', $adres, 'Güvenlik postasına tıklanacak bağlantı girmiş: '.$adres);
        }
    }
}
