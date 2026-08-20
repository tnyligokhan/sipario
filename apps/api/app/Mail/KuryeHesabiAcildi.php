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
        /**
         * Açılan hesabın GÖREVİ — "Kurye" ya da "Tezgâh" (2026-08-20).
         *
         * VARSAYILANI OLMASININ SEBEBİ SÖZLEŞMEDİR: bu posta 2026-08-12'den beri kurye için
         * gönderiliyordu ve mevcut çağrılar (panel, testler) alanı bilmiyor. Varsayılan, eski
         * davranışın birebir aynısını verir.
         */
        public readonly string $rolAdi = 'Kurye',
    ) {}

    protected function sablon(): string
    {
        return 'kurye-hesabi-acildi';
    }

    protected function konu(): string
    {
        return $this->kuryeAdi.' için '.mb_strtolower($this->rolAdi).' hesabı açıldı';
    }

    protected function onizleme(): string
    {
        return 'Giriş bilgileri: firma kodu '.$this->firmaKodu.' · kullanıcı adı '.$this->kullaniciAdi;
    }
}
