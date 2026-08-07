<?php

namespace App\Support\Geocoding;

use RuntimeException;

/**
 * Coğrafi kodlama SERVİS arızası — ağ, geçersiz anahtar, kota. "Adres bulunamadı" bu değildir
 * (o boş dizi ile döner).
 *
 * Mesaj kullanıcıya gösterilir: nötr, suçlayıcı değil ve ne yapacağını söyler. Sağlayıcının ham
 * hatası (anahtar/kota detayı) ASLA istemciye geçmez — sızıntı yüzeyi olur; log'a yazılır.
 */
class GeocodingException extends RuntimeException
{
    public static function ulasilamadi(): self
    {
        return new self('Adres servisine ulaşılamadı — birazdan tekrar deneyin.');
    }

    public static function yapilandirilmamis(): self
    {
        return new self('Adres servisi bu kurulumda tanımlı değil — konumu elle alın.');
    }

    public static function reddedildi(): self
    {
        return new self('Adres servisi isteği reddetti — destek ile görüşün.');
    }
}
