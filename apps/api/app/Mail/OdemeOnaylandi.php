<?php

namespace App\Mail;

use App\Livewire\Site\Forms\ParaBicimi;

/**
 * ÖDEME ONAYLANDI — panelden eşleştirme yapıldı, abonelik uzadı.
 *
 * BU POSTA BİR MAKBUZ DEĞİL, BİR "AÇILDI" HABERİDİR. Bayinin tek merak ettiği şey vardır:
 * "ne zamana kadar açığım?". O yüzden postanın kahraman rakamı tutar değil GEÇERLİLİK
 * TARİHİdir — para zaten ödendi, ödenen paranın ne satın aldığı önemlidir.
 *
 * E-ARŞİV FATURA BURADAN GİTMEZ. BRIEF fatura yükümlülüğünü ürünün parçası sayar ama fatura
 * ayrı bir belge akışıdır (mali mühür, GİB kanalı); bu postaya iliştirmek, gönderilmediği gün
 * postayı yalancı yapardı. Fatura akışı kurulduğunda buraya bir satır eklenir.
 */
class OdemeOnaylandi extends SiparioPostasi
{
    use ParaBicimi;

    public readonly string $tutar;

    public function __construct(
        public readonly string $isletme,
        int $tutarKurus,
        public readonly string $donem,
        public readonly string $gecerlilikBitisi,
        public readonly string $hesapUrl,
    ) {
        $this->tutar = $this->tl($tutarKurus);
    }

    protected function sablon(): string
    {
        return 'odeme-onaylandi';
    }

    protected function konu(): string
    {
        return 'Ödemeniz onaylandı, hesabınız açık';
    }

    protected function onizleme(): string
    {
        return 'Aboneliğiniz '.$this->gecerlilikBitisi.' tarihine kadar geçerli.';
    }
}
