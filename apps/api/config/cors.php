<?php

/*
|--------------------------------------------------------------------------
| CORS — Cross-Origin Resource Sharing (denetim bulgusu F4)
|--------------------------------------------------------------------------
|
| Laravel'in yayımlanmamış varsayılanı tüm origin'lere açıktır (`*`). Mobil bearer
| istemcisi CORS uygulamaz, ama Faz 5'te gelecek tarayıcı tabanlı site/panel için
| joker origin risktir. Bu yüzden yüzey `api/*` ile sınırlanır ve izinli origin'ler
| env'den okunur (üretimde yalnız sipario alan adları).
|
| supports_credentials=false: kimlik doğrulama bearer token ile yapılır (çerez yok),
| bu yüzden credentials'a gerek yoktur ve açık bırakmak gereksiz risktir.
|
*/

return [

    'paths' => ['api/*'],

    'allowed_methods' => ['*'],

    // Virgülle ayrık liste; tanımsızsa boş (hiçbir tarayıcı origin'ine izin yok — mobil etkilenmez).
    'allowed_origins' => array_values(array_filter(
        explode(',', (string) env('CORS_ALLOWED_ORIGINS', ''))
    )),

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
