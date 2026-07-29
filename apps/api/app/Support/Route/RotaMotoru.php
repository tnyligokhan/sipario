<?php

namespace App\Support\Route;

/**
 * Rota motorunun sözleşmesi — "şu durakları hangi sırayla gezeyim?".
 *
 * İki uygulaması var: kuş uçuşu en yakın komşu (saf, bedava, ASLA düşmez) ve Google Routes
 * (gerçek yol ağı, paralı, düşebilir). `RouteController` hangisinin bağlı olduğunu bilmez.
 *
 * KURAL — DEĞİŞMEZLER (her motor uymak zorunda):
 *  1. Dönen `order`, verilen durakların TAM bir permütasyonudur: hiçbir durak kaybolmaz,
 *     çoğalmaz. (Kaybolan durak = kuryenin uğramadığı müşteri.)
 *  2. Koordinatı olmayan duraklar sıralamaya girmez; SONA, aralarındaki göreli sıra korunarak
 *     eklenir ve sayıları `without_location` ile bildirilir. Dış servise HİÇ gönderilmezler.
 */
interface RotaMotoru
{
    public const GOOGLE = 'google';

    public const YAKIN_KOMSU = 'yakin-komsu';

    /**
     * @param  list<array{id: string, lat: float|null, lng: float|null}>  $duraklar
     * @param  array{lat: float, lng: float}|null  $baslangic  Cihazın anlık konumu. Verilirse zincir
     *                                                         BURAYA en yakın duraktan başlar; verilmezse listenin ilk durağı sabit kalır.
     * @return array{order: list<string>, without_location: int}
     *
     * @throws RotaException Servis arızası — çağıran yakın komşuya DÜŞMELİ, kullanıcıya yansıtmamalı.
     */
    public function sirala(array $duraklar, ?array $baslangic = null): array;

    /** Anahtar yapılandırılmış mı? Değilse motor hiç bağlanmaz, dış çağrı yapılmaz. */
    public function hazirMi(): bool;

    /**
     * Motorun yanıttaki `engine` etiketi (self::GOOGLE | self::YAKIN_KOMSU). Mobil bugün
     * okumuyor; sözleşmede durmasının sebebi TEŞHİS: bir sıra tuhaf göründüğünde "hangi motor
     * üretti, yoksa düşmüş müydü?" sorusu log'a inmeden cevaplanabilsin.
     */
    public function adi(): string;
}
