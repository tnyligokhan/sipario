<?php

namespace App\Enums;

/**
 * Bayi (tenant) yaşam döngüsü durumu. Değerler DB CHECK kısıtıyla birebir aynıdır.
 * - trial:     30 gün ücretsiz deneme (kayıt anındaki varsayılan)
 * - active:    abonelik ödenmiş (aylık veya yıllık — dönem tenants.billing_period'da)
 * - locked:    süre doldu, yazma kapalı (Faz 5 kilit akışı)
 * - suspended: BİZİM tarafımızdan elle askıya alındı (ödeyince geri açılır, hâlâ müşteri)
 * - cancelled: BAYİ bıraktı (churn). Yazma kapalı; veri SİLİNMEZ (BRIEF kırmızı çizgi #5).
 *
 * suspended ile cancelled bilerek ayrıdır: ilki tahsilat listesinde kalır, ikincisi churn sayacına
 * girer. Tek koda sıkıştırılsalardı erken terk oranı ölçülemezdi (BRIEF'in en pahalı metriği).
 *
 * Login yalnız trial/active durumlarına izin verir.
 */
enum TenantStatus: string
{
    case Trial = 'trial';
    case Active = 'active';
    case Locked = 'locked';
    case Suspended = 'suspended';
    case Cancelled = 'cancelled';

    /** Uygulamaya giriş (yazma) hakkı olan durumlar. */
    public function allowsLogin(): bool
    {
        return $this === self::Trial || $this === self::Active;
    }

    /**
     * Yazmanın DURUM sebebiyle kapalı olduğu haller (süre dolumu ayrı bir çıpadır —
     * bkz. SyncService::resolveLock). allowsLogin()'in tersi DEĞİLDİR diye ayrı durur:
     * ileride giriş açık ama yazma kapalı bir durum eklenirse ikisi ayrışacaktır.
     */
    public function writesLocked(): bool
    {
        return $this === self::Locked || $this === self::Suspended || $this === self::Cancelled;
    }
}
