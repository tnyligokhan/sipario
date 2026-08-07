<?php

namespace App\Support\Geocoding;

/**
 * Coğrafi kodlama sağlayıcısının sözleşmesi. Bugün Yandex, anahtar gelince Google; ikisi de
 * aynı yüzeyi verir ve `GeocodeController` hangisinin bağlı olduğunu bilmez.
 *
 * KURAL: sağlayıcı sonuç bulamazsa BOŞ DİZİ döner (istisna DEĞİL) — "bu adres bulunamadı"
 * normal bir sonuçtur. İstisna yalnız SERVİS arızasında (ağ, anahtar, kota) fırlatılır;
 * ikisini ayırmak kullanıcıya doğru cümleyi söyleyebilmek için şart.
 */
interface Geocoder
{
    /**
     * @param  string  $sorgu  Serbest adres metni (ör. "Bahçe Sk. no:5, Kepez").
     * @param  int  $enFazla  Döndürülecek en fazla aday.
     * @return list<GeoAday> Bulunamadıysa boş dizi.
     *
     * @throws GeocodingException Servis arızası (ağ/anahtar/kota) — kullanıcıya söylenecek.
     */
    public function ara(string $sorgu, int $enFazla): array;

    /** Anahtar yapılandırılmış mı? Değilse uç nokta hiç dış çağrı yapmaz. */
    public function hazirMi(): bool;
}
