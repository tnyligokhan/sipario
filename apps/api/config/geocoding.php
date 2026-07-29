<?php

/*
 * COĞRAFİ KODLAMA (adres → koordinat) — sağlayıcı SOYUT, anahtar YALNIZ SUNUCUDA.
 *
 * NEDEN SUNUCUDA: anahtar APK'ya gömülseydi ilk kurulumda çıkarılır ve kotamız yakılırdı.
 * İstemci `POST /api/v1/geocode`e serbest metin yollar; dışarıya çıkan tek veri o metindir
 * (ad/telefon/müşteri kimliği ASLA — kırmızı çizgi #4'ün mümkün olan en dar yorumu).
 *
 * Sağlayıcı env ile değişir: bugün yandex, anahtar gelince google. Kod tarafında tek satır
 * bile değişmez (GeocodingServiceProvider driver'a bakıp bağlar).
 */
return [
    // yandex | google | kademeli | null. (`coklu` = `kademeli` için eski ad, alias olarak yaşar.)
    //
    // `kademeli` (kullanıcı kararı 2026-07-29): her sorgu önce GOOGLE'a gider; YANDEX yalnız
    // Google bina kesinliğinde aday veremezse ve günlük tavana (aşağıda) kadar sorulur.
    // Sonuçlar BİRLEŞTİRİLMEZ — her aday kendi sağlayıcı etiketiyle ayrı satırdır, doğrusunu
    // kullanıcı seçer. Bir sağlayıcı arızalanırsa diğeri özelliği ayakta tutar; 503 ancak
    // hiçbiri cevap veremezse döner.
    //
    // `null` sürücüsü hiç dış çağrı yapmaz, boş liste döner — anahtarsız ortamda (CI, yerel
    // geliştirme) uygulama çalışmayı SÜRDÜRÜR, sessizce patlamaz.
    'driver' => env('GEOCODING_DRIVER', 'yandex'),

    // Aynı adres iki kez sorulmaz. Aday listesi kiracıdan bağımsızdır (kamuya açık coğrafi veri),
    // bu yüzden önbellek GLOBAL'dir — bir bayinin sorduğu "Bahçelievler Mah." diğerine bedavaya gelir.
    'cache_days' => (int) env('GEOCODING_CACHE_DAYS', 30),

    // Kullanıcıya gösterilecek en fazla aday. Tasarımdaki aday listesi 3 satır çizecek şekilde
    // kurgulandı; 5 üst sınır, seçimi zorlaştırmadan yanlış eşleşmeye ikinci şans verir.
    'max_results' => (int) env('GEOCODING_MAX_RESULTS', 5),

    // Saniye. İstemci 20 sn bekliyor; sunucu ondan ÖNCE pes etmeli ki kullanıcı "sunucuya
    // ulaşılamadı" yerine gerçek nedeni görsün.
    'timeout' => (int) env('GEOCODING_TIMEOUT', 8),

    // Kiracı başına GÜNLÜK üst sınır. Yandex'in ücretsiz kotası sınırlıdır ve tek bozuk istemci
    // döngüsü bütün bayilerin özelliğini kapatabilir. Aşımda 429 + nötr mesaj.
    'daily_limit' => (int) env('GEOCODING_DAILY_LIMIT', 300),

    // Aramayı Türkiye'ye yaklaştırır: "Bahçelievler" dünyada onlarca yerde vardır.
    'bias' => [
        'country' => env('GEOCODING_COUNTRY', 'tr'),
        'lang' => env('GEOCODING_LANG', 'tr_TR'),
        // Türkiye kabaca: batı-güney köşesi ve doğu-kuzey köşesi (lon,lat sırası).
        'bbox' => env('GEOCODING_BBOX', '25.5,35.8~45.0,42.2'),
    ],

    'yandex' => [
        'api_key' => env('YANDEX_GEOCODER_KEY', ''),
        // Yandex'in güncel uç noktası v1'dir; eski (1.x) anahtarlar için env ile geri alınabilir.
        'base_url' => env('YANDEX_GEOCODER_URL', 'https://geocode-maps.yandex.ru/v1/'),
        // GLOBAL günlük tavan (kiracı başına DEĞİL): Yandex'in 1000/gün limiti hesabın tamamına
        // aittir. Kademeli sürücü tavana ulaşınca Yandex'i o gün susturur — Google çalışmaya
        // devam eder, özellik düşmez. 900 = 1000'in altında bilinçli pay. 0 = sınırsız.
        'daily_limit' => (int) env('YANDEX_DAILY_LIMIT', 900),
    ],

    'google' => [
        'api_key' => env('GOOGLE_GEOCODER_KEY', ''),
        'base_url' => env('GOOGLE_GEOCODER_URL', 'https://maps.googleapis.com/maps/api/geocode/json'),
    ],
];
