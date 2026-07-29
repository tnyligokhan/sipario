<?php

namespace App\Support\Route;

use RuntimeException;

/**
 * Rota motoru arızası — ağ, geçersiz anahtar, kota, beklenmedik gövde, kapasite aşımı.
 *
 * Bu istisna KULLANICIYA HİÇ ULAŞMAZ: controller onu yakalar, log'a yazar ve yakın komşu
 * motoruna düşer. Mesaj bu yüzden LOG İÇİNDİR (teşhis), kullanıcı cümlesi değildir.
 *
 * KVKK (kırmızı çizgi #4): mesaja KOORDİNAT YAZILMAZ. Bir kapının enlem/boylamı bu bağlamda
 * kişisel veridir — hangi müşterinin nerede oturduğunu söyler. Yalnız durum kodu/sebep geçer.
 */
class RotaException extends RuntimeException
{
    public static function ulasilamadi(): self
    {
        return new self('Rota servisine ulaşılamadı.');
    }

    public static function yapilandirilmamis(): self
    {
        return new self('Rota servisi bu kurulumda tanımlı değil.');
    }

    public static function reddedildi(int $durum): self
    {
        return new self('Rota servisi isteği reddetti (HTTP '.$durum.').');
    }

    public static function beklenmedikYanit(): self
    {
        return new self('Rota servisi beklenmedik bir gövde döndü.');
    }

    public static function kapasiteAsildi(int $adet, int $tavan): self
    {
        return new self('Ara durak sayısı servis tavanını aşıyor ('.$adet.' > '.$tavan.').');
    }
}
