<?php

namespace App\Mail;

/**
 * GÜNLÜK YEDEK BİLDİRİMİ — BİZE gelen posta. Bayiye gitmez.
 *
 * NEDEN DOSYA EKLENMEZ, LİNK GÖNDERİLİR: yedek sıkıştırılmış da olsa büyür ve çoğu SMTP
 * sağlayıcısı 25 MB üstünü reddeder — üstelik reddi SESSİZ olur. Dahası e-posta eki
 * sağlayıcının sunucusunda süresiz durur; link, panel girişinin arkasındadır ve erişimi
 * her indirmede yeniden sorulur.
 *
 * ⚠️ KONU SATIRINDA "Sipario ·" ÖN EKİ VAR — `IcBildirim` ile aynı gerekçe: bu posta bizim
 * kutumuza düşer ve ön ek orada bir SÜZGEÇ ANAHTARIDIR. Müşteriye giden postalarda bu ön ek
 * yasaktır.
 *
 * ⚠️ POSTANIN İÇİNDE MÜŞTERİ VERİSİ YOKTUR — yalnız dosya adı, boyut, tarih ve bir bağlantı.
 * Verinin kendisi bağlantının ardındadır ve oraya `auth:admin` olmadan girilemez.
 */
class YedekHazir extends SiparioPostasi
{
    /**
     * @param  array<string, string>  $satirlar  E-postada gösterilecek olgular (ad, boyut, tarih).
     */
    public function __construct(
        public readonly string $indirmeUrl,
        public readonly array $satirlar,
        public readonly string $geriYuklemeKomutu,
        public readonly string $tarihEtiketi,
        public readonly bool $bayat = false,
        public readonly string $bayatUyarisi = '',
    ) {}

    protected function sablon(): string
    {
        return 'yedek-hazir';
    }

    protected function konu(): string
    {
        return 'Sipario · Günlük yedek — '.$this->tarihEtiketi;
    }

    protected function onizleme(): string
    {
        return $this->bayat
            ? 'Dikkat: yedek tazelenmemiş olabilir.'
            : 'Veritabanı yedeği indirilmeye hazır.';
    }
}
