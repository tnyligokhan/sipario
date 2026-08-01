<?php

namespace App\Panel;

/**
 * Panelden GİRİLEN telefon numarasının normalleştirilmesi (5c-3 · D3/D4).
 *
 * Mobil istemci numarayı zaten E.164 biçiminde gönderir; panelde numarayı İNSAN yazar ya da CSV'den
 * gelir ("0532 111 22 33", "532-111-22-33", "+90 532 111 2233" hepsi aynı numaradır). Tek biçime
 * indirgemek yalnız güzellik değil DOĞRULUK meselesidir: arayan tanıma `phone_last10` üzerinden
 * eşleşir, CSV dedup'ı da öyle — biçim farkı aynı müşteriyi iki kez yaratırdı.
 *
 * TR varsayımı BİLİNÇLİ: ürün Türkiye pazarındadır ve mobil taraf da 10 haneyi +90 ile eşler.
 * Ülke kodu belli olmayan 10 haneli girdi +90 sayılır; bunun dışındaki uluslararası numara
 * '+' ile başlatılarak yazılabilir ve olduğu gibi korunur.
 */
class Telefon
{
    /** Ham girdiyi E.164'e çevirir; anlamlı bir numara çıkmıyorsa null. */
    public static function e164(?string $ham): ?string
    {
        $ham = trim((string) $ham);
        if ($ham === '') {
            return null;
        }

        $uluslararasi = str_starts_with($ham, '+');
        $rakam = preg_replace('/\D/', '', $ham) ?? '';

        if ($uluslararasi) {
            return strlen($rakam) >= 10 ? '+'.$rakam : null;
        }

        // 0532…  →  90532…   |   90532… zaten ülke kodlu   |   532… (10 hane) → +90 eklenir
        if (strlen($rakam) === 11 && str_starts_with($rakam, '0')) {
            $rakam = '90'.substr($rakam, 1);
        } elseif (strlen($rakam) === 10) {
            $rakam = '90'.$rakam;
        }

        return strlen($rakam) >= 12 ? '+'.$rakam : null;
    }

    /** Eşleşme anahtarı: son 10 hane (arayan tanıma ve dedup bunun üzerinden çalışır). */
    public static function son10(?string $ham): ?string
    {
        $rakam = preg_replace('/\D/', '', (string) $ham) ?? '';

        return strlen($rakam) >= 10 ? substr($rakam, -10) : null;
    }
}
