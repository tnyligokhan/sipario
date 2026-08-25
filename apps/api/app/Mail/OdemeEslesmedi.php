<?php

namespace App\Mail;

use App\Livewire\Site\Forms\ParaBicimi;

/**
 * ÖDEME EŞLEŞMEDİ — panelden reddedildi.
 *
 * BU ŞABLONUN ZOR KISMI TASARIM DEĞİL, DİL. `OdemeBildirimServisi::reddet()` bir durum makinesi
 * geçişidir ve teknik adı "rejected"tır; ama bu postayı okuyan insan parayı gönderdiğine
 * inanıyor. "Reddedildi" demek onu yalancı ilan etmektir ve gerçekte en olası sebep bu değildir:
 * açıklamaya referans kodu yazılmamıştır, havale başka bir hesaba gitmiştir, ya da para henüz
 * bankaya düşmemiştir. Bu yüzden posta boyunca fail YOKTUR — yalnız "eşleştiremedik" vardır ve
 * sebep bizim tarafımızda da olabilir.
 *
 * VERİ REHİN ALINMAZ (BRIEF kırmızı çizgi #5): bu posta bir kapanış bildirimi değildir. Sonu
 * her zaman açık bir kapıdır — yanıtla, ara, tekrar dene.
 */
class OdemeEslesmedi extends SiparioPostasi
{
    use ParaBicimi;

    public readonly string $tutar;

    public function __construct(
        public readonly string $isletme,
        int $tutarKurus,
        public readonly string $referans,
        public readonly string $beyanTarihi,
        public readonly string $abonelikUrl,
        public readonly string $not = '',
    ) {
        $this->tutar = $this->tl($tutarKurus);
    }

    protected function sablon(): string
    {
        return 'odeme-eslesmedi';
    }

    protected function konu(): string
    {
        return 'Ödemenizi bulamadık, birlikte bakalım';
    }

    protected function onizleme(): string
    {
        return $this->beyanTarihi.' tarihli bildiriminiz hesabımızda görünmüyor.';
    }
}
