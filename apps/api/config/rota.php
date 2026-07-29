<?php

/*
 * OTO SIRALAMA (rota) — motor SOYUT, anahtar YALNIZ SUNUCUDA.
 *
 * NEDEN SOYUT: sıralama iki şekilde yapılabiliyor — kuş uçuşu en yakın komşu (bedava, saf, hiç
 * düşmez) ya da Google Routes (gerçek yol ağı, trafiksiz sürüş süresi, paralı). Hangisinin
 * bağlandığını controller BİLMEZ; env'deki tek satır seçer, mobil taraf farkı görmez.
 *
 * NEDEN YIKILMAZ: Google motoru arızalanırsa (anahtar, kota, ağ, >25 durak) istisna atar ve
 * controller SESSİZCE yakın komşuya düşer. Kullanıcı 5xx görmez, kontörü boşa yanmaz — yalnız
 * sıra biraz daha kaba olur. Yani ödeme/kota tarafındaki her arıza özelliği DÜŞÜRMEZ.
 */
return [
    // google | yakin-komsu. Tanınmayan değer yakın komşuya düşer (yanlış yazım özelliği kapatmasın).
    // `google` seçilse bile anahtar boşsa bağlama kendiliğinden yakın komşuyu kurar.
    'surucu' => env('ROTA_SURUCU', 'yakin-komsu'),

    'google' => [
        // Coğrafi kodlamadaki Google anahtarıyla AYNI proje anahtarı olabilir — ama konsolda
        // "Routes API" de etkinleştirilmiş ve anahtar kısıtlamasına eklenmiş olmalıdır.
        'api_key' => env('GOOGLE_ROUTES_KEY', ''),
        'base_url' => env('GOOGLE_ROUTES_URL', 'https://routes.googleapis.com/directions/v2:computeRoutes'),
    ],

    // Saniye. Sıralama kullanıcı BEKLERKEN olur; sunucu geç kalmaktansa yakın komşuya düşmeli.
    'timeout' => (int) env('ROTA_TIMEOUT', 8),
];
