<?php

namespace App\Support\Geocoding;

/**
 * Sağlayıcı yapılandırılmamışken bağlanan sürücü — dış çağrı YAPMAZ.
 *
 * Neden var: anahtar bir insan işidir ve gelmeden önce de CI koşar, yerel geliştirme yapılır,
 * demo veri hazırlanır. Bu sürücü olmasaydı ya kod anahtarsız ortamda patlardı ya da testler
 * gerçek servise çıkardı. `hazirMi()` false döner; uç nokta bunu görüp dürüst bir "bu kurulumda
 * tanımlı değil" mesajı verir — sessizce boş liste göstermek "adres bulunamadı" yalanı olurdu.
 */
final class NullGeocoder implements Geocoder
{
    public function hazirMi(): bool
    {
        return false;
    }

    /** @return list<GeoAday> */
    public function ara(string $sorgu, int $enFazla): array
    {
        throw GeocodingException::yapilandirilmamis();
    }
}
