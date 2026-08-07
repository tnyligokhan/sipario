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
}
