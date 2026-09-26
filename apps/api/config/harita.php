<?php

/*
 * HARİTA KAROLARI — CARTO basemaps, anahtar YALNIZ SUNUCUDA (2026-09-26).
 *
 * NEDEN: CARTO anahtarsız karo vermeyi kesti; anahtarsız istek 200 ile "API KEY REQUIRED"
 * yazılı bir filigran görsel döndürüyor (ölçüldü: her karo aynı 2049 bayt, ETag `wm-…`).
 * Anahtar APK'ya gömülseydi çıkarılıp kotamız yakılırdı (coğrafi kodlamadaki kuralın aynısı);
 * uygulama karoyu `GET /api/v1/harita/karo/...` üzerinden ister, sunucu anahtarı ekler.
 */
return [
    // carto.com/basemaps/apikey — boşsa uç nokta dışarı HİÇ çıkmaz (filigran indirmek yerine
    // 503 döner; uygulama karoyu gri bırakır, pinler durur).
    'carto_key' => env('CARTO_BASEMAPS_KEY'),

    // Gün. Karo kiracıdan bağımsız, kamuya açık görseldir; bir bayinin indirdiği karo diğerine
    // CARTO'ya gitmeden gelir. Ticari ücretsiz sınır ayda 1 milyon istek — önbellek o sınırın
    // asıl koruyucusudur.
    'onbellek_gun' => (int) env('HARITA_KARO_ONBELLEK_GUN', 30),

    // Saniye. Karo küçük bir görseldir; takılan tek bir istek haritanın tamamını bekletmemeli.
    'timeout' => (int) env('HARITA_KARO_TIMEOUT', 6),

    // Kullanıcı başına dakikalık karo isteği. Bir ekran açılışı 20-40 karo, hızlı kaydırma ve
    // yakınlaştırma yüzlerce ister; genel `throttle:api` (60/dk) haritayı yarım bırakırdı.
    'dakika_limit' => (int) env('HARITA_KARO_DAKIKA_LIMIT', 900),
];
