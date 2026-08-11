<?php

namespace App\Mail;

/**
 * SÜRE DOLDU — hesap yazmaya kapandı.
 *
 * BU ON DÖRT ŞABLONUN EN HASSASIDIR. Bayi bu postayı, uygulamanın kilitlendiğini gördüğü gün
 * okur; o an ürüne duyduğu güvenin sınandığı andır ve aklındaki soru satış değildir:
 * "müşteri listem ve veresiye defterim ne oldu?"
 *
 * O YÜZDEN POSTANIN İLK VE EN BÜYÜK CÜMLESİ VERİ GÜVENCESİDİR, ÖDEME ÇAĞRISI DEĞİL. BRIEF
 * kırmızı çizgi #5 bunu ürünün sözü olarak yazar ("veri rehin alınmaz: abonelik bitse ve sistem
 * kilitlense bile bayinin verisi silinmez"). Bir söz ancak tam da şüphe edildiği anda
 * tekrarlanırsa güven üretir; bu posta o andır.
 *
 * ÜÇ ŞEY BİLEREK YAZILIR:
 *  - Ne DURDU: yalnız yazma. Okumak ve dışa aktarım talebi açık.
 *  - Ne DURMADI: telefonda bekleyen kayıtlar sunucuya akmaya devam eder (senkron kilitte de
 *    çalışır) — yani kilit ANINDA girilmiş son siparişler kaybolmaz.
 *  - Nasıl geri gelir: ödeme yapıldığı an her şey olduğu gibi açılır.
 */
class SureDoldu extends SiparioPostasi
{
    public function __construct(
        public readonly string $isletme,
        public readonly string $yetkili,
        public readonly string $bitisTarihi,
        public readonly string $abonelikUrl,
        public readonly bool $denemeydi = false,
    ) {}

    protected function sablon(): string
    {
        return 'sure-doldu';
    }

    protected function konu(): string
    {
        return $this->denemeydi
            ? 'Deneme süreniz doldu — verileriniz duruyor'
            : 'Aboneliğiniz sona erdi — verileriniz duruyor';
    }

    protected function onizleme(): string
    {
        return 'Hiçbir kaydınız silinmedi; abonelik başladığı an her şey olduğu gibi geri gelir.';
    }
}
