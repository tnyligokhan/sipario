<?php

namespace App\Mail;

/**
 * ABONELİK YENİLEME HATIRLATMASI — T-15 / T-3.
 *
 * `DenemeBitiyor` İLE AYNI ŞABLON DEĞİL, ÇÜNKÜ AYNI İNSAN DEĞİL. Denemedeki bayi henüz ürüne
 * güvenmemiş bir adaydır; buradaki bayi bir yıl parasını ödemiş, ürünü her gün kullanan bir
 * müşteridir. Ona "aboneliği başlat" diye seslenmek, geçen yılı yok saymaktır. Bu posta önce
 * teşekkür eder, sonra hatırlatır.
 *
 * BU PROJEDE OTOMATİK TAHSİLAT YOKTUR: ödeme havale/EFT ya da elden yürür (`OdemeBildirimServisi`).
 * Yani "kartınızdan çekilecek" diye bir cümle KURULAMAZ — yenileme bayinin ELLE yapacağı bir
 * eylemdir ve hatırlatmanın tek işi o eylemi zamanında tetiklemektir.
 */
class YenilemeHatirlatmasi extends SiparioPostasi
{
    public function __construct(
        public readonly string $isletme,
        public readonly string $yetkili,
        public readonly int $kalanGun,
        public readonly string $bitisTarihi,
        public readonly string $abonelikUrl,
        public readonly string $yillikTutar = '',
    ) {}

    protected function sablon(): string
    {
        return 'yenileme-hatirlatmasi';
    }

    protected function konu(): string
    {
        return 'Aboneliğiniz '.$this->bitisTarihi.' tarihinde yenilenmeli';
    }

    protected function onizleme(): string
    {
        return $this->kalanGun.' gün kaldı · ödemenizi şimdi yaparsanız kesinti olmaz.';
    }
}
