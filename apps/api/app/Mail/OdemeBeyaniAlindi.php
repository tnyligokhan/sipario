<?php

namespace App\Mail;

use App\Livewire\Site\Forms\ParaBicimi;

/**
 * "ÖDEME BEYANINIZ ALINDI" — bayi "Havale yaptım" ya da "Beni arayın" dedikten sonra.
 *
 * NEDEN VAR: beyan aboneliği UZATMAZ (`OdemeBildirimServisi` bilinçli olarak yalnız bir kayıt
 * açar; parayı gördüğümüzde biz eşleştiririz). Yani bayi düğmeye basar, ekranda bir bildirim
 * görür ve sonra HİÇBİR ŞEY olmaz — hesabı hâlâ kapalıdır. Bugün o boşlukta bayi ne beklediğini
 * ve ne kadar bekleyeceğini bilmiyor; en olası davranışı ikinci kez ödeme yapmaya kalkışmak ya
 * da bizi aramak. Bu posta beklentiyi yazılı hâle getirir.
 *
 * SÖZ VERMEZ, SÜREÇ ANLATIR: "hesabınız açıldı" DEMEZ — açılmadı. Ne olduğunu, sıradaki adımın
 * bizde olduğunu ve sonucun yine e-postayla geleceğini söyler.
 */
class OdemeBeyaniAlindi extends SiparioPostasi
{
    use ParaBicimi;

    public readonly string $tutar;

    public readonly string $yontemAdi;

    public function __construct(
        public readonly string $isletme,
        int $tutarKurus,
        public readonly string $referans,
        string $yontem,
        public readonly string $beyanTarihi,
    ) {
        $this->tutar = $this->tl($tutarKurus);
        $this->yontemAdi = $yontem === 'elden' ? 'Elden tahsilat' : 'Havale / EFT';
    }

    protected function sablon(): string
    {
        return 'odeme-beyani-alindi';
    }

    protected function konu(): string
    {
        return 'Ödeme bildiriminizi aldık';
    }

    protected function onizleme(): string
    {
        return $this->tutar.' tutarındaki bildiriminiz kontrol sırasında.';
    }
}
