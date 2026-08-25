<?php

namespace App\Mail;

/**
 * DENEME BİTİYOR — T-7 / T-3 / T-1 hatırlatması.
 *
 * BRIEF'İN "ERKEN TERK" KORKUSUNUN TAM MERKEZİ. Bugün bu posta yok: bayi bir sabah uygulamayı
 * açıyor ve kilitli buluyor. O an ürünü bırakmak için yeterli bir sürprizdir ve kaybedilen bayi
 * geri gelmez. Üç hatırlatma, sürprizi bir plana çevirir.
 *
 * ÜÇ AYRI ŞABLON DEĞİL, TEK ŞABLON + KALAN GÜN: metin kalan güne göre sertleşir ama yapı aynı
 * kalır. Üç ayrı dosya, üçünden birinin bakımsız kalması demekti.
 *
 * FİYAT BURADA GÖSTERİLİR — mağaza kuralı bunu YASAKLAMAZ. BRIEF'in yasağı MOBİL UYGULAMA
 * YÜZEYİ içindir ("uygulamada fiyat yok, buton yok, link yok"); e-posta web kanalıdır ve
 * BRIEF web için tam tersini söyler: "Web'de fiyat, paket ve Abone Ol butonu gösterilir."
 */
class DenemeBitiyor extends SiparioPostasi
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
        return 'deneme-bitiyor';
    }

    protected function konu(): string
    {
        return match (true) {
            $this->kalanGun <= 1 => 'Deneme süreniz yarın bitiyor',
            default => 'Deneme sürenizin bitmesine '.$this->kalanGun.' gün kaldı',
        };
    }

    protected function onizleme(): string
    {
        return $this->bitisTarihi.' tarihinden sonra kayıt girişi durur; verileriniz silinmez.';
    }
}
