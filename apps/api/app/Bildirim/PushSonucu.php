<?php

namespace App\Bildirim;

/**
 * Tek bir gönderimin sonucu. Çağıranın vereceği karar buna bağlıdır ve dördü de FARKLI
 * davranış ister — hepsini "başarısız" saymak ya ölü jetonları sonsuza dek denemeye ya da
 * geçici bir ağ arızasında bildirimi büsbütün kaybetmeye yol açar.
 */
enum PushSonucu
{
    /** Gitti. */
    case Basarili;

    /** Push sistemi yapılandırılmamış — hata değil, kapalı (bkz. `config/push.php`). */
    case Kapali;

    /** Cihaz jetonu ölü (uygulama silinmiş/veri temizlenmiş): jeton veritabanından silinmeli. */
    case JetonOlu;

    /** Ağ ya da FCM tarafı geçici arıza: kuyruk yeniden denemeli. */
    case Gecici;

    /** Yük ya da yetki hatalı: yeniden denemek aynı sonucu verir, kuyruk meşgul edilmemeli. */
    case Kalici;
}
