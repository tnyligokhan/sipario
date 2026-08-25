<?php

namespace App\Mail;

use App\Livewire\Site\Forms\ParaBicimi;
use App\Models\AddonPackage;

/**
 * EK PAKET TANIMLANDI — panelden bayiye kurye hakkı ya da rota kontörü eklendi.
 *
 * NEDEN POSTA GEREKİR: ek paket TELEFONDA KONUŞULUP panelde tanımlanır (birebir satış). Bayi
 * için bu, karşılığında para ödediği ama hiçbir belgesi olmayan bir işlemdir — "kaç kurye
 * hakkım oldu, ne zaman tanımlandı" sorusunun yazılı tek cevabı bu postadır.
 *
 * BEDELSİZ TANIMLAMA AYRI KONUŞUR: `EkPaketServisi` 'bedelsiz' tahsilat yolunu tanır (jest,
 * telafi, deneme uzatma). Bedelsiz bir paketi "ödemeniz alındı" diliyle bildirmek yanlış olurdu;
 * şablon tutar sıfırsa metni değiştirir.
 */
class EkPaketTanimlandi extends SiparioPostasi
{
    use ParaBicimi;

    public readonly string $tutar;

    public readonly bool $bedelsiz;

    public readonly string $turAdi;

    public function __construct(
        public readonly string $isletme,
        public readonly string $paketAdi,
        string $tur,
        public readonly int $adet,
        int $tutarKurus,
        public readonly string $tanimlamaTarihi,
        public readonly string $hesapUrl,
    ) {
        $this->tutar = $this->tl($tutarKurus);
        $this->bedelsiz = $tutarKurus === 0;
        $this->turAdi = $tur === AddonPackage::TYPE_COURIER ? 'Kurye hakkı' : 'Rota kontörü';
    }

    protected function sablon(): string
    {
        return 'ek-paket-tanimlandi';
    }

    protected function konu(): string
    {
        return $this->paketAdi.' hesabınıza tanımlandı';
    }

    protected function onizleme(): string
    {
        return $this->adet.' adet '.mb_strtolower($this->turAdi).' eklendi.';
    }
}
