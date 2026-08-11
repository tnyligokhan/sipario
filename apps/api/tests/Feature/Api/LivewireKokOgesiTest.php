<?php

namespace Tests\Feature\Api;

use App\Livewire\Site\Parola;
use App\Livewire\Site\ParolaYenile;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * LIVEWIRE KÖK ÖĞESİ — "kök koşullu olamaz".
 *
 * 2026-08-11'de canlıda tarayıcıyla ÖLÇÜLDÜ: parola sıfırlama sayfasındaki düğme hiçbir istek
 * üretmiyordu. Sunucu erişim günlüğünde tek satır yoktu, tarayıcının Network sekmesi de boştu.
 *
 * Sebep: Livewire kök özniteliklerini (`wire:id`/`wire:snapshot`) şu düzenli ifadeyle yerleştirir
 * (`Livewire\Drawer\Utils::insertAttributesIntoHtmlRoot`):
 *
 *     /(?:\n|^)(\s*)<([a-zA-Z0-9\-]+)/
 *
 * yani kök etiketin SATIR BAŞINDA olmasını şart koşar. Görünüm `@if` ile başlayınca Livewire'ın
 * kendi `<!--[if BLOCK]><![endif]-->` işaretçisi araya girer ve gerçek kök etiket onunla AYNI
 * SATIRDA kalır. Regex onu göremez, bir SONRAKİ satır başındaki etikete atlar — bizim durumumuzda
 * kabuğun soldaki dekoratif `<aside>`ine. Form `<section>` tarafında, yani kökün DIŞINDA kalır ve
 * `wire:submit` hiç bağlanmaz; düğme formu tarayıcının kendi GET'iyle gönderir.
 *
 * ⚠️ BU ARIZAYI MEVCUT HİÇBİR KAPI GÖREMİYORDU ve sebebi öğreticidir:
 *   • `Livewire::test()` YEŞİL geçiyor — sunucu tarafı bileşen kusursuz çalışıyor, sorun
 *     yalnız çıktının HTML iskeletinde.
 *   • Tarayıcı konsolunda hata YOK, tüm varlıklar 200, `window.Livewire` yüklü ve bileşen
 *     kayıtlı görünüyor.
 *   • Kullanıcıya görünen tek şey "düğme çalışmıyor".
 * Bu yüzden iddia DAVRANIŞA değil ÇIKTININ İSKELETİNE bakar: kök öğe hangisi?
 */
class LivewireKokOgesiTest extends ApiTestCase
{
    /**
     * Bir bileşenin HTML'inde `wire:snapshot`ın taşındığı etiketi döner.
     *
     * Etiket adını almak yeter; asıl iddia "kök, İÇİNDE `wire:` yönergesi olan öğeleri
     * kapsıyor mu"dur ve bunu aşağıdaki testler ayrıca sınar.
     */
    private function kokEtiketi(string $html): ?string
    {
        return preg_match('/<([a-zA-Z0-9\-]+)[^>]*\swire:snapshot/', $html, $m) ? $m[1] : null;
    }

    #[Test]
    public function parola_ekraninda_kok_oge_formu_kapsar(): void
    {
        $html = Livewire::test(Parola::class)->html();

        $this->assertSame('main', $this->kokEtiketi($html),
            'Livewire kökü kabuğun <main> etiketi olmalı. <aside> çıkıyorsa görünüm koşullu bir '
            .'kökle başlıyordur ve form kökün dışında kalmıştır — düğme sessizce ölür.');

        $this->kokFormuKapsiyorMu($html, 'wire:submit="gonder"');
    }

    #[Test]
    public function parola_yenile_ekraninda_kok_oge_formu_kapsar(): void
    {
        // Sıfırlama akışının İKİNCİ yarısı. Kardeşi onarılıp burası unutulsaydı arıza bir adım
        // öteye taşınırdı: bayi bağlantıya tıklar, parolasını yazar, düğme hiçbir şey yapmaz.
        $html = Livewire::test(ParolaYenile::class, ['token' => 'x', 'email' => 'a@b.com'])->html();

        $this->assertSame('main', $this->kokEtiketi($html));
        $this->kokFormuKapsiyorMu($html, 'wire:submit="kaydet"');
    }

    /**
     * ASIL İDDİA: `wire:snapshot` taşıyan etiketin AÇILIŞI, verilen yönergeden ÖNCE gelmeli ve
     * o etiket henüz kapanmamış olmalı. Yalnız kök etiket adına bakmak yetmez — kök doğru etikete
     * konsa bile form onun dışında kalabilir.
     */
    private function kokFormuKapsiyorMu(string $html, string $yonerge): void
    {
        $kokKonum = strpos($html, 'wire:snapshot');
        $yonergeKonum = strpos($html, $yonerge);

        $this->assertNotFalse($kokKonum, 'wire:snapshot hiç yok — bileşen render olmamış.');
        $this->assertNotFalse($yonergeKonum, "$yonerge çıktıda yok.");
        $this->assertLessThan($yonergeKonum, $kokKonum,
            "$yonerge, wire:snapshot taşıyan kök öğeden ÖNCE geliyor — yani kökün dışında.");

        // Kök etiket, yönergeden önce kapanmamalı.
        $kokEtiket = $this->kokEtiketi($html);
        $kapanis = strpos($html, "</$kokEtiket>");
        if ($kapanis !== false) {
            $this->assertGreaterThan($yonergeKonum, $kapanis,
                "Kök <$kokEtiket> etiketi $yonerge'den ÖNCE kapanıyor — yönerge kökün dışında "
                .'kalıyor ve Livewire onu hiç bağlamaz.');
        }
    }

    #[Test]
    public function hicbir_livewire_gorunumu_kosullu_bir_kokle_baslamaz(): void
    {
        // Kaynak seviyesinde SINIF BEKÇİSİ: yukarıdaki iki test yalnız bilinen iki ekranı korur;
        // bu, yarın yazılacak üçüncü ekranı da korur. `@php` bilerek listede DEĞİL — o bir morph
        // işaretçisi üretmez, dolayısıyla kökü kaydırmaz.
        $kosullu = ['if', 'foreach', 'forelse', 'unless', 'switch', 'for', 'while', 'isset', 'empty', 'auth', 'guest', 'can'];
        $desen = '/^@('.implode('|', $kosullu).')\b/';

        $kok = resource_path('views/livewire');
        $dosyalar = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($kok));

        $ihlal = [];
        foreach ($dosyalar as $dosya) {
            if (! $dosya->isFile() || ! str_ends_with($dosya->getFilename(), '.blade.php')) {
                continue;
            }
            // Alt çizgiyle başlayan dosyalar PARÇAdır (`@include` ile gömülür), bileşen kökü değil.
            if (str_starts_with($dosya->getFilename(), '_')) {
                continue;
            }

            $icerik = (string) file_get_contents($dosya->getPathname());
            $icerik = preg_replace('/\{\{--.*?--\}\}/s', '', $icerik) ?? $icerik;

            if (preg_match($desen, ltrim($icerik))) {
                $ihlal[] = str_replace($kok.DIRECTORY_SEPARATOR, '', $dosya->getPathname());
            }
        }

        $this->assertSame([], $ihlal,
            'Bu görünümler koşullu bir kökle başlıyor; Livewire kök özniteliklerini yanlış öğeye '
            ."koyar ve içerideki wire: yönergeleri SESSİZCE ölür:\n  - ".implode("\n  - ", $ihlal)
            ."\nÇözüm: tek bir kök öğe kullanın, koşulu onun İÇİNE alın.");
    }
}
