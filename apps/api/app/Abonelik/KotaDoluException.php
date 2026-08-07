<?php

namespace App\Abonelik;

use RuntimeException;

/**
 * Kurye hesabı kotası dolu — yeni kurye açılamaz (App\Abonelik\KuryeKotasi).
 *
 * Mesaj bilinçli olarak NÖTRdür ve satın almaya yönlendirmez: bu istisna bir gün mobil API'ye
 * bağlanırsa, mağaza kuralı (BRIEF pazarlıksız maddesi) uygulamada fiyat/paket/"abone ol" ifadesini
 * YASAKLAR. Yönlendirme metni yalnız web ve panel katmanında eklenir.
 */
class KotaDoluException extends RuntimeException
{
    public function __construct(public readonly int $limit, public readonly int $kullanilan)
    {
        parent::__construct('Kurye hesabı hakkınız dolu. Destek alın.');
    }
}
