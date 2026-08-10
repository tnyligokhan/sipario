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

    /**
     * Kişiye özel kurye yetkisi ATAYABİLİR Mİ? (2026-08-10, migration 004008.)
     *
     * Yetki alanları senkron yoluyla yazılabilir hâle geldiği an, kapısı olmayan bir `user_profile`
     * push'u YETKİ YÜKSELTME VEKTÖRÜDÜR: kurye kendi cihazından kendi satırına
     * `courier_can_discount: true` yazıp bayinin kapattığı iskontoyu açabilirdi — üstelik offline
     * kuyruktan, patron hiçbir şey görmeden. `ProfileChangeApplier` kimlik yüzeyini (rol/e-posta/
     * parola) zaten aynı gerekçeyle dışarıda tutar; yetki alanları o yüzeyin devamıdır.
     *
     * OPERATÖR DAHİLDİR: bayide günlük işi o çevirir ve kurye ekibini o düzenler (Ekip ekranı
     * operatöre açıktır). Kurye HARİÇTİR — kendi yetkisini de başkasınınkini de yazamaz.
     *
     * Ad/telefon/aktiflik yazımı BU KAPIYA TABİ DEĞİLDİR: kurye kendi telefonunu güncelleyebilir,
     * o bir yetki değil iletişim bilgisidir.
     */
    public function kuryeYetkisiAtayabilir(): bool
    {
        return $this === self::Patron || $this === self::Operator;
    }
}
