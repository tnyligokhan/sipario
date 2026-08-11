<?php

namespace App\Mail;

/**
 * KURYE HESABI AÇILDI — patron web panelinden yeni bir kurye ekledi.
 *
 * ALICI KURYE DEĞİL, PATRONDUR. Kurye hesabının e-postası GERÇEK DEĞİLDİR: `Provisioning::
 * createCourier` onu `<kullanıcı>@<firma-kodu>.sipario.local` diye türetir (yorumunda "e-posta
 * yalnız teknik bir zorunluluktur" yazar). O adrese gönderilen posta hiçbir yere ulaşmaz.
 * Giriş bilgilerini kuryeye ulaştıracak olan patrondur; posta da ona gider.
 *
 * PAROLA YAZILMAZ. Patron parolayı formda kendisi belirledi, yani zaten biliyor; postaya
 * kopyalamak bilgiyi eklemez, yalnız posta kutusunu ele geçiren birine hazır bir hesap verir.
 * Postanın işi parolayı hatırlatmak değil, kuryenin GİRİŞ İÇİN NE YAZACAĞINI (firma kodu +
 * kullanıcı adı) kayda geçirmektir — bunlar formda bir kez görünüp kaybolur.
 */
class KuryeHesabiAcildi extends SiparioPostasi
{
    public function __construct(
        public readonly string $isletme,
        public readonly string $kuryeAdi,
        public readonly string $kullaniciAdi,
        public readonly string $firmaKodu,
        public readonly int $kalanHak,
        public readonly string $hesapUrl,
    ) {}

    protected function sablon(): string
    {
        return 'kurye-hesabi-acildi';
    }

    protected function konu(): string
    {
        return $this->kuryeAdi.' için kurye hesabı açıldı';
    }

    protected function onizleme(): string
    {
        return 'Giriş bilgileri: firma kodu '.$this->firmaKodu.' · kullanıcı adı '.$this->kullaniciAdi;
    }
}
