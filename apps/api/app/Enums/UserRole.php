<?php

namespace App\Enums;

/**
 * Bayi içindeki kullanıcı rolleri. DECISIONS: ayrı roles tablosu/paket yok, tek `role`
 * sütunu yeterli. Değerler DB'deki CHECK kısıtıyla (patron,operator,kurye) birebir aynıdır.
 */
enum UserRole: string
{
    case Patron = 'patron';
    case Operator = 'operator';
    case Kurye = 'kurye';
}
