<?php

namespace App\Support\Geocoding;

/**
 * Bir adres sorgusunun TEK adayı. Sağlayıcıdan bağımsız biçim — Yandex de Google da buna çevrilir,
 * istemci hangi servisin konuştuğunu bilmez (sağlayıcı değişince mobil taraf hiç değişmez).
 *
 * [kesinlik] ham sağlayıcı kelimesi DEĞİL, normalize edilmiş üç kademedir: bina / sokak / semt.
 * Kullanıcı adayı seçerken "bu bina mı yoksa sokağın ortası mı" bilgisi kurye için farkı yaratır.
 */
final readonly class GeoAday
{
    public const KESINLIK_BINA = 'bina';

    public const KESINLIK_SOKAK = 'sokak';

    public const KESINLIK_SEMT = 'semt';

    public const KAYNAK_YANDEX = 'yandex';

    public const KAYNAK_GOOGLE = 'google';

    /**
     * [kaynak] adayı HANGİ sağlayıcının bulduğu. Tek sağlayıcılı kurulumda bilgi niteliğindedir;
     * `coklu` sürücüde ise LİSTENİN ANLAMINI taşır — iki sağlayıcı aynı noktayı gösteriyorsa
     * `'google+yandex'` olur ve bu, kullanıcıya "ikisi de burayı işaret etti" demenin yoludur.
     * Kesinlik kademesi tek bir servisin kendine olan güvenidir; MUTABAKAT ondan güçlü bir sinyaldir.
     */
    public function __construct(
        public string $metin,
        public float $lat,
        public float $lng,
        public string $kesinlik = self::KESINLIK_SEMT,
        public string $kaynak = '',
    ) {}

    /** @return array{text: string, lat: float, lng: float, precision: string, source: string} */
    public function toArray(): array
    {
        return [
            'text' => $this->metin,
            'lat' => $this->lat,
            'lng' => $this->lng,
            'precision' => $this->kesinlik,
            'source' => $this->kaynak,
        ];
    }

    /** Kesinlik kademesi sayıya: bina 3 > sokak 2 > semt 1. Karşılaştırma için. */
    public function kesinlikDerecesi(): int
    {
        return match ($this->kesinlik) {
            self::KESINLIK_BINA => 3,
            self::KESINLIK_SOKAK => 2,
            default => 1,
        };
    }

    /**
     * İki aday AYNI YERİ mi gösteriyor? Eşik 25 metre — bilinçli olarak DAR.
     *
     * Geniş bir eşik (ör. 100 m) iki sağlayıcının gerçekten ayrıştığı durumları "aynı" sayıp
     * birini listeden silerdi; oysa kurye için 60 metre yanlış apartman demektir ve hangisinin
     * doğru olduğuna kullanıcı bakarak karar vermeli. Bu yüzden yalnız pratikte AYNI nokta olan
     * adaylar birleştirilir; ayrışanlar listede YAN YANA durur — zaten iki sağlayıcı kullanmanın
     * sebebi budur.
     */
    public function ayniYerMi(self $digeri): bool
    {
        // Equirectangular yaklaşımı: Türkiye enlemlerinde ve 25 m ölçeğinde hatası ihmal edilebilir,
        // haversine'in trigonometri maliyetine gerek yok.
        $enlemMetre = ($this->lat - $digeri->lat) * 111_320.0;
        $boylamMetre = ($this->lng - $digeri->lng) * 111_320.0 * cos(deg2rad($this->lat));

        return sqrt($enlemMetre ** 2 + $boylamMetre ** 2) <= 25.0;
    }

    /**
     * Koordinat Türkiye sınırlarında mı? Sağlayıcı ülke ipucuna rağmen yurt dışı sonuç
     * döndürebilir ("Bahçelievler" Kosova'da da var); kuryeyi 900 km öteye gönderecek adayı
     * listeye HİÇ koymayız.
     */
    public function turkiyedeMi(): bool
    {
        return $this->lat >= 35.5 && $this->lat <= 42.5
            && $this->lng >= 25.0 && $this->lng <= 45.5;
    }
}
