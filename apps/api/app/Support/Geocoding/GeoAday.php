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
     * [kaynak] adayı HANGİ sağlayıcının bulduğu ('yandex' | 'google' | ''). Kademeli sürücüde
     * listenin okunma biçimidir: kullanıcı "Google şunu buldu, Yandex bunu" diye görür ve
     * doğrusunu KENDİSİ seçer (kullanıcı kararı 2026-07-29 — adaylar birleştirilmez).
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
