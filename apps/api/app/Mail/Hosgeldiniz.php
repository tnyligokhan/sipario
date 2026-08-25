<?php

namespace App\Mail;

/**
 * HOŞ GELDİNİZ — işletme açıldı, deneme başladı.
 *
 * İKİ KAPIDAN DA ÇIKAR: siteden kayıt (`Livewire\Site\Register`) ve bizim panelden elle açma
 * (birebir satışla kazanılan bayi — BRIEF: "siteden kaydolmayan bayiler için elle açma"). İkisinde
 * de bayinin ihtiyacı AYNIdır, o yüzden tek şablon: firma kodunu ve kullanıcı adını öğrenmek.
 *
 * BU POSTANIN İŞİ SATIŞ DEĞİL, İLK GİRİŞ. BRIEF'in en büyük korkusu üçüncü sırada yazıyor:
 * "kurulum→ilk tanıma 10 dakikanın altında kalmalı". Bayi kayıt ekranını kapattığı an firma
 * kodunu kaybeder ve uygulamaya giremez — mobil giriş firma kodu + kullanıcı adı ister, e-posta
 * kabul etmez. Bu yüzden kod postanın en büyük ve tek başına duran öğesidir.
 *
 * FİYAT VE ÖDEME BAĞLANTISI BİLEREK YOK: deneme daha yeni başladı, satış konuşmanın vakti değil;
 * ayrıca postanın ekran görüntüsü mağaza incelemesine düşerse tartışma açmasın.
 *
 * PAROLA POSTAYA YAZILMAZ. Bayi parolayı kayıt ekranında kendi belirledi; postaya kopyalamak,
 * posta kutusunu ele geçiren herkese hesabı vermek olurdu.
 */
class Hosgeldiniz extends SiparioPostasi
{
    public function __construct(
        public readonly string $isletme,
        public readonly string $yetkili,
        public readonly string $firmaKodu,
        public readonly string $kullaniciAdi,
        public readonly string $denemeBitisi,
        public readonly int $denemeGun,
        public readonly string $hesapUrl,
    ) {}

    protected function sablon(): string
    {
        return 'hosgeldiniz';
    }

    protected function konu(): string
    {
        return $this->isletme.' için Sipario hesabınız hazır';
    }

    protected function onizleme(): string
    {
        return 'Firma kodunuz '.$this->firmaKodu.' · deneme süreniz '.$this->denemeBitisi.' tarihinde bitiyor.';
    }
}
