<?php

namespace App\Enums;

/**
 * Bir erişim token'ı NEDEN düşürüldü? (2026-08-22 — tek hesap, tek cihaz.)
 *
 * Değer `personal_access_tokens.revoked_reason` sütununda yaşar. Sebebi saklamanın tek amacı
 * İSTEMCİYE DÜRÜST BİR CÜMLE KURDURMAKTIR: token'ı silseydik sonraki istek çıplak bir 401
 * alırdı ve bayi ekranda sebepsiz bir çıkış görürdü. Kullanıcıya "neden çıktım" sorusunu
 * sordurtmamak, bu özelliğin destek maliyetinin tamamıdır.
 *
 * [istemciKodu] sözleşmenin parçasıdır: mobil istemci METNE değil bu koda bakar (metin
 * değişince istemci kırılmasın).
 */
enum TokenDusmeSebebi: string
{
    /** Aynı hesap başka bir telefonda açıldı; bu cihazın oturumu kapandı. */
    case BaskaCihaz = 'baska_cihaz';

    public function istemciKodu(): string
    {
        return match ($this) {
            self::BaskaCihaz => 'oturum_baska_cihazda',
        };
    }

    public function mesaj(): string
    {
        return match ($this) {
            self::BaskaCihaz => 'Hesabınız başka bir cihazda açıldı, bu cihazdaki oturum kapatıldı',
        };
    }
}
