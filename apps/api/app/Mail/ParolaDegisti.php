<?php

namespace App\Mail;

/**
 * PAROLANIZ DEĞİŞTİ — güvenlik teyidi.
 *
 * NEDEN VAR: parola sıfırlama akışı bugün sessizdir. Bir saldırgan bayinin posta kutusuna
 * eriştiyse sıfırlama bağlantısını kullanır, parolayı değiştirir ve hesabın sahibi bunu ancak
 * giremediği gün fark eder. Bu posta o penceredeki tek uyarıdır.
 *
 * BU POSTA BİR EYLEM DÜĞMESİ TAŞIMAZ — bilerek. "Ben değiştirmediysem tıkla" diyen bir düğme,
 * kimlik avı postalarının birebir taklit ettiği kalıptır; bayiyi o kalıba alıştırmak, yarın
 * sahtesini tıklamasını kolaylaştırır. Tek çağrı: bu iletiyi YANITLA (yani zaten güvendiği
 * kanal üzerinden bize ulaş).
 *
 * NE ZAMAN, NEREDEN: zaman ve şehir/IP gibi bir ayrıntı olmadan "parolanız değişti" cümlesi
 * kullanıcıya karar verdirmez. Zaman yazılır; IP YAZILMAZ (KVKK kırmızı çizgi #4 — kişisel
 * veriyi çoğaltmıyoruz, hem de bayi kendi IP'sini tanımaz, bilgi değil gürültü olurdu).
 */
class ParolaDegisti extends SiparioPostasi
{
    public function __construct(
        public readonly string $yetkili,
        public readonly string $zaman,
    ) {}

    protected function sablon(): string
    {
        return 'parola-degisti';
    }

    protected function konu(): string
    {
        return 'Sipario parolanız değiştirildi';
    }

    protected function onizleme(): string
    {
        return $this->zaman.' · bunu siz yapmadıysanız hemen bize yazın.';
    }
}
