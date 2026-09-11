<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\CustomerImport;
use App\Models\AdminUser;
use App\Models\Customer;
use App\Support\Provisioning;
use Illuminate\Http\UploadedFile;
use Livewire\Features\SupportTesting\Testable;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * MÜŞTERİ AKTARIM EKRANININ ADIMLI AKIŞI (2026-09-11).
 *
 * Servisin adım mantığı `PanelImportGenisSutunTest`te sınanıyor; burada sınanan şey EKRANIN o
 * adımları bitene kadar SÜRDÜRMESİ ve sayaçları doğru göstermesi.
 *
 * NEDEN AYRI TEST: zaman aşımı çözümü iki parçalıdır ve ikinci parça tamamen bu bileşendedir —
 * servis "kalan var" diyebilir ama ekran `devam`ı kapatırsa aktarım yarıda kalır ve kimse
 * fark etmez (sonuç kartı "başarılı" der, müşterilerin yarısı yoktur). O yüzden burada
 * doğrulanan şey SAYILAR DEĞİL, DÖNGÜNÜN KAPANMASIDIR.
 */
class PanelImportAdimliUiTest extends ApiTestCase
{
    private function admin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Aktarım Admin', 'email' => 'adimli@sipario.test',
            'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /** Aktarım ekranını, yüklenmiş ve önizlenmiş bir dosyayla açar. */
    private function ekran(string $tenantId, string $icerik): Testable
    {
        return Livewire::test(CustomerImport::class, ['tenant' => $tenantId])
            ->set('dosya', UploadedFile::fake()->createWithContent('musteriler.csv', $icerik))
            ->call('onizle');
    }

    /** @param int $adet kaç müşteri satırı üretilecek */
    private function icerik(int $adet): string
    {
        $satirlar = ['ad;telefon;adres;bolge;not;kod;favoriler'];
        for ($i = 0; $i < $adet; $i++) {
            $satirlar[] = 'Müşteri '.$i.';053'.str_pad((string) $i, 9, '0', STR_PAD_LEFT)
                .';Adres '.$i.';Muratpaşa;;'.(3000 + $i).';Tombul Tüp';
        }

        return implode("\n", $satirlar)."\n";
    }

    #[Test]
    public function aktar_dugmesi_hicbir_sey_yazmadan_ilerleme_kartini_acar(): void
    {
        // Düğmeye basınca tarayıcı onlarca saniye taş gibi durmamalı: ilk adımı `wire:poll`
        // tetikler, düğme yalnız ilerleme kartını açar.
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        $ekran = $this->ekran($a['tenant']->id, $this->icerik(3))->call('uygula');

        $ekran->assertSet('devam', true);
        $this->assertSame(3, $ekran->get('ilerleme')['toplam']);
        $this->assertSame(0, $ekran->get('ilerleme')['yazilan']);
        $this->assertSame(0, $this->asOwner(fn () => Customer::query()->count()),
            'Düğme HİÇBİR ŞEY yazmamalı — yazma adımlarda olur.');
    }

    #[Test]
    public function ekran_adimlari_bitene_kadar_surdurur(): void
    {
        // 200 satır: parti olay tavanını (500) aşar, yani aktarım gerçekten birden çok adıma
        // bölünür. Ekran `devam` true olduğu sürece `adim()` çağrılır.
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        $ekran = $this->ekran($a['tenant']->id, $this->icerik(200))->call('uygula');

        $tur = 0;
        while ($ekran->get('devam') === true) {
            $ekran->call('adim');
            $this->assertLessThan(300, ++$tur, 'Adımlar ilerlemiyor — sonsuz döngü riski.');
        }

        $this->assertSame(200, $this->asOwner(fn () => Customer::query()->count()),
            'Ekran aktarımı sonuna kadar sürdürmeli.');
        $this->assertSame(200, $ekran->get('sonuc')['eklenen']);
        $this->assertSame('applied', $ekran->get('sonuc')['durum']);
        $this->assertNull($ekran->get('onizleme'), 'Bitince önizleme kartı kapanmalı.');
    }

    #[Test]
    public function atlanan_sayaci_adimlar_boyunca_sismez(): void
    {
        // TUZAK: ikinci adımda, birinci adımda YAZILMIŞ satırlar dedup'tan 'atlanacak' gelir.
        // Sayaç her adımda tazelenseydi kullanıcı sonunda "200 satır atlandı" görür ve
        // aktarımın başarısız olduğunu sanardı. Sayaç İLK önizlemeden alınır, bir daha değil.
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        // Dosyada bilerek TEK bir tekrar var: 200 satırın sonuna aynı kodu ikinci kez koy.
        $icerik = rtrim($this->icerik(200), "\n")."\n"
            .'Tekrar;0539 000 00 99;Adres;Muratpaşa;;3000;'."\n";

        $ekran = $this->ekran($a['tenant']->id, $icerik)->call('uygula');
        $this->assertSame(1, $ekran->get('ilerleme')['atlanan']);

        while ($ekran->get('devam') === true) {
            $ekran->call('adim');
        }

        $this->assertSame(1, $ekran->get('sonuc')['atlanan'],
            'Atlanan sayacı adımlar boyunca şişmemeli.');
        $this->assertSame(200, $ekran->get('sonuc')['eklenen']);
    }

    #[Test]
    public function acilan_urunler_adimlar_boyunca_tekrarlanmaz(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        $ekran = $this->ekran($a['tenant']->id, $this->icerik(200))->call('uygula');
        while ($ekran->get('devam') === true) {
            $ekran->call('adim');
        }

        $this->assertSame(['Tombul Tüp'], $ekran->get('sonuc')['acilan_urunler'],
            'Ürün her adımda yeniden "açıldı" diye listelenmemeli.');
    }

    #[Test]
    public function eklenecek_satir_yoksa_adima_hic_girilmez(): void
    {
        $a = $this->makeTenant('a');
        $this->actingAs($this->admin(), 'admin');

        // Aynı dosyayı iki kez: ikincisinde her satır dedup'tan atlanır.
        $icerik = $this->icerik(3);
        $this->ekran($a['tenant']->id, $icerik)->call('uygula')->call('adim');

        $ekran = $this->ekran($a['tenant']->id, $icerik)->call('uygula');

        $ekran->assertSet('devam', false);
        $this->assertSame(0, $ekran->get('sonuc')['eklenen']);
        $this->assertSame(3, $ekran->get('sonuc')['atlanan']);
    }
}
