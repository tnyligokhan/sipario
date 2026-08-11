<?php

namespace App\Mail;

use App\Livewire\Site\Forms\ParaBicimi;

/**
 * HAVALE/EFT TALİMATI — "bilgileri e-posta ile gönder" düğmesinin çıktısı.
 *
 * BUNUN YERİNE GEÇTİĞİ ŞEY: `Livewire\Site\Subscribe::bilgileriPostala()` içindeki `Mail::raw`
 * düz metin bloğu. O blok bilgiyi boşluklarla hizalıyordu ("IBAN         : TR..") — telefonda
 * orantılı yazı tipiyle o hizalama dağılır ve IBAN okunmaz hâle gelir.
 *
 * BU POSTA PARA TAŞIR, O YÜZDEN TASARIMI SÜS DEĞİL: bayi IBAN'ı ya elle bankacılık uygulamasına
 * yazacak ya da kopyalayacak. Üç değer (IBAN, tutar, referans) mono ve kopyalanabilir bloklarda
 * durur; referans kodu ayrıca TEK BAŞINA büyükçe tekrarlanır çünkü havale açıklamasına o
 * yazılmazsa ödeme elle eşleştirilmek zorunda kalır ve bayinin hesabı geç açılır.
 *
 * ⚠️ ŞİRKET KÜNYESİ YER TUTUCU OLABİLİR. `config/subscription.php` bugün "[Şirket IBAN]" gibi
 * köşeli parantezli değerler taşıyor ve bunu BİLEREK yapıyor. Çağıran taraf bu postayı yer
 * tutucu IBAN'la göndermemelidir; buradaki iş biçimlendirmek, doğrulamak değil.
 */
class HavaleTalimati extends SiparioPostasi
{
    use ParaBicimi;

    public readonly string $tutar;

    public function __construct(
        public readonly string $unvan,
        public readonly string $banka,
        public readonly string $iban,
        int $tutarKurus,
        public readonly string $referans,
    ) {
        // Para biçimi sitenin `tl()`siyle AYNI kaynaktan gelir: postada "5.988 ₺", ekranda
        // "5.988,00 ₺" görmek bayide "hangisi doğru" sorusunu doğururdu.
        $this->tutar = $this->tl($tutarKurus);
    }

    protected function sablon(): string
    {
        return 'havale-talimati';
    }

    protected function konu(): string
    {
        return 'Havale bilgileriniz ve '.$this->referans.' referans kodu';
    }

    protected function onizleme(): string
    {
        return $this->tutar.' · açıklamaya '.$this->referans.' yazmayı unutmayın.';
    }
}
