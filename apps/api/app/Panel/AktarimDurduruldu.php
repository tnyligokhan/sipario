<?php

namespace App\Panel;

use RuntimeException;

/**
 * Toplu aktarımın ORTASINDA senkron çekirdeği bir partiyi kabul etmediğinde fırlatılır
 * (kilitli bayi, reddedilen olay). Exception olması bilinçlidir: `rlsIcinde` transaction'ını
 * geri sarar ve dosyanın YARISI yazılmış hâlde kalmasını önler — kullanıcı 300 satırlık dosyayı
 * yeniden yüklerse ilk 150'nin çift yazılması, "kısmen aktarıldı" demekten çok daha kötüdür.
 */
class AktarimDurduruldu extends RuntimeException
{
    public function __construct(public readonly string $durum, ?string $mesaj = null)
    {
        parent::__construct($mesaj ?? 'Aktarım uygulanamadı ('.$durum.').');
    }
}
