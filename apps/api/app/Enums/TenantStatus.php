<?php

namespace App\Enums;

/**
 * Bayi (tenant) yaşam döngüsü durumu. Değerler DB CHECK kısıtıyla birebir aynıdır.
 * - trial:     30 gün ücretsiz deneme (kayıt anındaki varsayılan)
 * - active:    yıllık abonelik ödenmiş
 * - locked:    süre doldu, yazma kapalı (Faz 5 kilit akışı)
 * - suspended: bizim tarafımızdan elle askıya alındı
 *
 * Faz 1'de login yalnız trial/active durumlarına izin verir.
 */
enum TenantStatus: string
{
    case Trial = 'trial';
    case Active = 'active';
    case Locked = 'locked';
    case Suspended = 'suspended';

    /** Uygulamaya giriş (yazma) hakkı olan durumlar. */
    public function allowsLogin(): bool
    {
        return $this === self::Trial || $this === self::Active;
    }
}
