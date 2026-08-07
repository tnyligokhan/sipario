<?php

namespace App\Support\Route;

/**
 * Kuş uçuşu en yakın komşu motoru — `RouteOrderer`'ın motor sözleşmesine takılmış hâli.
 *
 * NEDEN SARMALAYICI (RouteOrderer'a interface eklemek yerine): `RouteOrderer` SAF kalmalı —
 * statik, Laravel'siz, HTTP'siz. Ucuz birim testleri onu doğrudan çağırıyor; sınıfı örneğe
 * ve arayüze bağlamak o testleri bedelsiz yere ağırlaştırırdı.
 *
 * BU MOTOR ASLA DÜŞMEZ. Ağı, anahtarı, kotası yok; `hazirMi()` her zaman true. Özelliğin
 * "hiçbir koşulda 5xx vermez" güvencesi tam olarak buradan gelir: paralı motor ne yaparsa
 * yapsın, arkada her zaman cevap veren bir motor durur.
 */
final class YakinKomsuMotoru implements RotaMotoru
{
    /**
     * @param  list<array{id: string, lat: float|null, lng: float|null}>  $duraklar
     * @param  array{lat: float, lng: float}|null  $baslangic
     * @return array{order: list<string>, without_location: int}
     */
    public function sirala(array $duraklar, ?array $baslangic = null): array
    {
        return RouteOrderer::sirala($duraklar, $baslangic);
    }

    public function hazirMi(): bool
    {
        return true;
    }

    public function adi(): string
    {
        return self::YAKIN_KOMSU;
    }
}
