<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * GENEL SİTE İÇERİK DÜRÜSTLÜĞÜ — sayfa ziyaretçiye yalan söylemesin (2026-08-05).
 *
 * `SiteGezinmeTest` gezinme YÜZEYİNİ kilitler (menü, alt bilgi, bağlantı hedefleri). Bu dosya
 * ayrı bir sözleşmeyi kilitler: sayfanın GÖVDESİNDE ne yazdığını. İki ayrı sorumluluk, iki ayrı
 * dosya — aynı dosyaya yığılsalardı bir kuralı değiştiren diğerini de kırardı.
 *
 * NEDEN DB'Yİ TAZELEMİYOR: `migrate:fresh` YOK. Sayfalar `plans` ve `addon_packages`'ı yalnız
 * OKUR (PlanDeposu · EkPaketServisi); şema kurmak gerekmez. Eşzamanlı vardiyalarda `migrate:fresh`
 * koşan bir test, başka testin altındaki tabloyu siliyor ve sahte kırıklar üretiyordu — bu dosya
 * o yarışa hiç girmez.
 *
 * NEYİ KORUYOR — üçü de SESSİZ kusurdu, hiçbiri sayfayı 500 yapmıyordu:
 *   1. Künye/kanal alanlarının config varsayılanı köşeli parantezlidir ("[Telefon]"). Gerçek değer
 *      girilene kadar ziyaretçi kırık kutular görüyordu. Süzgeç `_veri.php`de; biri kaldırırsa
 *      hiçbir şey 500 vermez, sayfa yine 200 döner — yalnız yer tutucular geri gelir.
 *   2. "Kurumsal" diye bir plan `plans` tablosunda hiç olmadı; site onu satılıyormuş gibi
 *      gösteriyordu. Plan kaldırıldı, adının artıklarının geri sızmaması gerekiyor.
 *   3. EN İNCESİ: /destek'in giriş cümlesi telefonla aramayı vaat ediyordu ("aynı numara",
 *      "ilk aramada çözülüyor") ama ekranda telefon kanalı yoktu. Veriyi süzüp metni olduğu gibi
 *      bırakmak sessiz bir yalan üretir; cümle artık kanal listesine bağlı ve bu test o bağı
 *      İKİ YÖNDE birden sınar.
 */
class SiteIcerikTest extends TestCase
{
    /** Yer tutucu deseni — `SiteGezinmeTest`'in alt bilgi için kullandığıyla aynı. */
    private const YER_TUTUCU = '/\[[^\]]{3,40}\]/u';

    /**
     * Sayfanın ZİYARETÇİYE GÖRÜNEN metni.
     *
     * `<script>`/`<style>` içerikleri ÖNCE atılır: `strip_tags` yalnız etiketleri söker, gövdeyi
     * bırakır — Livewire'ın gömdüğü stil bloğu `[wire\:loading]` gibi köşeli parantezli seçiciler
     * taşır ve yer tutucu iddiasını sahte kırmızıya düşürürdü. (Bu tuzağa ölçüm sırasında bizzat
     * düştük; ölçüt burada tek yerde tanımlı ki iki test aynı şeyi iki farklı şekilde ölçmesin.)
     */
    private function gorunurMetin(string $adres): string
    {
        $govde = $this->get($adres)->assertOk()->getContent();
        $metin = strip_tags(preg_replace('#<(script|style)\b[^>]*>.*?</\1>#su', ' ', $govde));

        /*
         * BOŞA GEÇMEYE KARŞI KİLİT. "Yer tutucu YOK" iddiası, metin yanlışlıkla boşalırsa da
         * geçerdi — süzgeç fazla kırpsa (ör. desen tüm gövdeyi yutsa) test sessizce yeşil kalır
         * ve hiçbir şeyi korumaz. Sayfanın gerçekten okunur metin döndürdüğünü önce kanıtlıyoruz.
         */
        $this->assertGreaterThan(
            500,
            mb_strlen(trim($metin)),
            $adres.' için görünür metin şüpheli derecede kısa — süzgeç gövdeyi yutmuş olabilir.'
        );
        $this->assertStringContainsString('Sipario', $metin, $adres.' gövdesi beklenen metni taşımıyor.');

        return $metin;
    }

    #[Test]
    public function genel_sayfalarda_koseli_parantezli_yer_tutucu_gorunmez(): void
    {
        // Kullanıcının gördüğü kusur buydu: "[Şirket unvanı]", "[Telefon]", "[MERSİS no]" ekranda.
        // Üç sayfa da künye/kanal verisini okuyor, üçü de kapalı kalmalı.
        foreach (['/', '/destek', '/iletisim'] as $adres) {
            $this->assertDoesNotMatchRegularExpression(
                self::YER_TUTUCU,
                $this->gorunurMetin($adres),
                $adres.' sayfasında hâlâ köşeli parantezli yer tutucu basılıyor.'
            );
        }
    }

    #[Test]
    public function iletisim_sayfasi_yer_tutucu_kunyeyi_basmaz(): void
    {
        /*
         * "Merkez" panosunun dört alanı (unvan/adres/MERSİS/vergi dairesi) da bugün yer tutucu,
         * o yüzden pano HİÇ kurulmuyor. Mevzuat karşılığı kapalı: satıcı künyesi mesafeli satış
         * sözleşmesi ve ön bilgilendirme formunda duruyor (bkz. SiteGezinmeTest'in alt bilgi
         * testi) — künyeyi gizlemiyoruz, YER TUTUCUSUNU gizliyoruz.
         */
        $this->get('/iletisim')
            ->assertOk()
            ->assertDontSee('MERSİS')
            ->assertDontSee('il-adres', false);
    }

    #[Test]
    public function iletisim_konu_listesinde_olu_plan_adi_gecmez(): void
    {
        $govde = $this->get('/iletisim')->assertOk()->getContent();

        preg_match('/<select id="il-konu".*?<\/select>/s', $govde, $m);
        $this->assertNotEmpty($m, 'Konu listesi <select id="il-konu"> bulunamadı.');

        // Seçenek SİLİNMEDİ, adı düzeltildi: çok şubeli bayi gerçek bir satış kanalı ve o talep
        // bize hâlâ geliyor — silmek talebin kendisini görünmez yapardı. Kilitlenen şey bu ayrım.
        $this->assertStringNotContainsString('Kurumsal', $m[0]);
        $this->assertStringContainsString('Çok şubeli işletme', $m[0]);
    }

    #[Test]
    public function destek_giris_cumlesi_telefon_kanali_yokken_aramayi_vaat_etmez(): void
    {
        // Bugünkü hâl: config'de telefon yer tutucu → kanal süzülür → cümle aramaya atıf yapamaz.
        config(['subscription.company.phone' => '[Telefon]']);

        $this->get('/destek')
            ->assertOk()
            ->assertDontSee('aynı numara')
            ->assertDontSee('ilk aramada')
            ->assertSee('Bot yok, otomatik yanıt yok.');
    }

    #[Test]
    public function destek_giris_cumlesi_telefon_kanali_varken_aramayi_vaat_eder(): void
    {
        /*
         * Bağın İKİNCİ yönü. Bu olmadan önceki test, cümleyi "Bot yok…" diye SABİTLEYEREK de
         * geçerdi — yani veriye bağlılığı değil, yalnız bugünkü metni kilitlerdi. Gerçek numara
         * girildiği gün tasarımın kendi cümlesinin geri gelmesi de bir sözleşme.
         */
        config(['subscription.company.phone' => '0850 000 00 00']);

        $this->get('/destek')
            ->assertOk()
            ->assertSee('aynı numara')
            ->assertSee('ilk aramada')
            ->assertDontSee('Bot yok, otomatik yanıt yok.');
    }

    /*
     * ══════════════════════════════════════════════════════════════════════════════════════
     * 2026-09-01 — ÜÇ YENİ SÖZLEŞME
     *
     * Üçü de aynı türden: sitenin, ürünün GERÇEĞİYLE çelişen bir şey söylememesi. Bu dosyanın
     * kuruluş gerekçesiyle birebir aynı ("sayfa ziyaretçiye yalan söylemesin") — yalnız bu kez
     * yalanı doğuran şey eksik veri değil, DEĞİŞEN KARARLARDI.
     * ══════════════════════════════════════════════════════════════════════════════════════
     */

    /** Ziyaretçiye görünen metni okuyan sayfalar — üç iddianın ortak tarama alanı. */
    private const PAZARLAMA_SAYFALARI = ['/', '/ozellikler', '/fiyatlar', '/destek', '/hakkimizda'];

    #[Test]
    public function hicbir_sayfa_verinin_turkiyede_saklandigini_soylemez(): void
    {
        /*
         * ⚠️ SUNUCU TÜRKİYE'DE DEĞİL — ÖLÇÜLDÜ (2026-09-01): Hostinger, Frankfurt / Almanya
         * (`srv1577146.hstgr.cloud`, AS47583). BRIEF md.4'teki "veri Türkiye'de" kırmızı çizgisi
         * kullanıcı tarafından açıkça kaldırıldı (gerekçe: Türkiye'de sunucu maliyeti).
         *
         * İddia SEKİZ AYRI YERDE yaşıyordu: ana sayfa güvence kartı, alt bilgi rozeti, giriş
         * ekranı kutusu, destek SSS'i, Hakkımızda, gizlilik politikası, aydınlatma metni ve
         * veri işleyen eki. Sekizini birden elle takip etmek, birini unutmak demektir — bu test
         * onların hepsini tek desenle tarıyor.
         *
         * ⚠️ HUKUK BELGELERİ DE TARANIYOR ve bu kasıtlı: yanlış barındırma beyanı bir pazarlama
         * hatası değil, KVKK aydınlatma yükümlülüğünün ihlalidir.
         */
        $sayfalar = array_merge(self::PAZARLAMA_SAYFALARI, array_map(
            fn (string $slug): string => route('legal.show', $slug, false),
            ['kvkk-aydinlatma', 'gizlilik-politikasi', 'veri-isleyen', 'iptal-iade', 'mesafeli-satis', 'on-bilgilendirme'],
        ));

        foreach ($sayfalar as $adres) {
            $metin = strip_tags($this->get($adres)->assertOk()->getContent());

            // Apostrof iki biçimde de yazılabiliyor (' ve ’) — desen ikisini de kapsamalı.
            $this->assertDoesNotMatchRegularExpression(
                '/Türkiye[\'’]de(ki)?\s+(bulunan\s+)?sunucu/u',
                $metin,
                $adres.' hâlâ verinin Türkiye\'deki sunucuda durduğunu söylüyor — sunucu Frankfurt\'ta.'
            );
            $this->assertStringNotContainsString('Veriler Türkiye', $metin, $adres.' eski rozeti/kartı basıyor.');
        }
    }

    #[Test]
    public function pazarlama_sayfalari_odenmis_donem_icin_iade_vaat_etmez(): void
    {
        /*
         * Kullanıcı kararı 2026-09-01: *"İptal ve iade diye bir şey yok zaten 30 günlük deneme
         * süresi var."* Kaldırılan iki taahhüt (ilk 14 gün koşulsuz tam iade · sonrasında
         * kullanılmayan aylar oranında iade) satış sayfalarında üç yerde geçiyordu: ödeme
         * güvencesi kartı ve iki SSS cevabı.
         *
         * ⚠️ TARAMA YALNIZ PAZARLAMA SAYFALARINDA. Hukuk belgeleri BİLEREK dışarıda: iade
         * hâlâ üç durumda yapılıyor (hatalı/mükerrer tahsilat, hizmetin durdurulması, satın
         * alınan bir işlevin kaldırılması) ve o cümleler /yasal/iptal-iade'de yazılı olmak
         * ZORUNDA. Deseni oraya da uygulamak, kendi kusurumuzun bedelini üstlendiğimiz
         * maddeleri sildirirdi.
         */
        foreach (self::PAZARLAMA_SAYFALARI as $adres) {
            $metin = strip_tags($this->get($adres)->assertOk()->getContent());

            foreach (['koşulsuz iade', 'iade ediyoruz', 'oranında iade', 'tamamını iade'] as $vaat) {
                $this->assertStringNotContainsString(
                    $vaat,
                    $metin,
                    $adres.' hâlâ iade vaat ediyor ("'.$vaat.'") — taahhüt 2026-09-01'."'".'de kaldırıldı.'
                );
            }
        }
    }

    #[Test]
    public function ozellikler_sayfasi_uygulama_maketi_basmaz(): void
    {
        /*
         * Kullanıcı: *"Uygulama içinden görüntülerin sürekli gösteriliyor olması çok kötü."*
         * Sayfada ALTI telefon maketi vardı (hero + beş anlatı bölümü). Hepsi kaldırıldı.
         *
         * Ölçüt maketin kök sınıfı: `x-site.telefon` her zaman `<div class="t-cerceve">` basar.
         * Metne değil YAPIYA bakmak önemli — bileşen yeniden kullanıldığı an test kırılır,
         * kopya değişse de.
         *
         * ⚠️ ANA SAYFA BİLEREK KAPSAM DIŞI: orada maket iddianın kanıtıdır (telefon çalıyor,
         * kart ekranda). Kaldırılan şey görsel değil, aynı görselin altıncı kez tekrarıydı.
         */
        $this->get('/ozellikler')->assertOk()->assertDontSee('t-cerceve', false);
        $this->get('/')->assertOk()->assertSee('t-cerceve', false);
    }
}
