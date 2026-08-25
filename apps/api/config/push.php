<?php

/*
|--------------------------------------------------------------------------
| PUSH BİLDİRİMİ (FCM HTTP v1)
|--------------------------------------------------------------------------
|
| KİMLİK BİLGİSİ YOKSA SİSTEM KAPALIDIR VE BU BİR HATA DEĞİLDİR: yerel geliştirmede,
| testte ve Firebase kurulmadan önceki üretimde push sessizce atlanır. Sebep mimari:
| push bu üründe bir HIZLANDIRICIDIR, taşıyıcı değil — dürtü hiç gitmese de veri mevcut
| senkronla akar. Bu yüzden eksik yapılandırma bir iş akışını düşüremez.
|
| `FCM_HIZMET_HESABI` — Firebase konsolundan inen hizmet hesabı JSON'unun BASE64 hâli.
| Neden base64: dosya çok satırlıdır ve `private_key` alanı gömülü `\n` taşır; Coolify'ın
| ortam değişkeni kutusuna ham hâlini yapıştırmak satır sonlarını bozar ve imza sessizce
| geçersizleşir (hata "invalid_grant" olarak FCM'den döner, sebebi görünmez). Tek satırlık
| base64 bu sınıf arızayı tamamen kapatır. Ham JSON da kabul edilir (yerel kolaylık).
|
| ⚠️ BU DEĞER SIRDIR. Repoya konmaz; sızarsa üçüncü taraf bayilerimizin telefonlarına
| bildirim gönderebilir. `google-services.json` ise sır DEĞİLDİR (APK'nın içinde zaten
| dağıtılır, anahtarı paket adına kısıtlıdır) — o repoda durur.
*/

return [

    'fcm' => [
        'hizmet_hesabi' => env('FCM_HIZMET_HESABI'),

        /*
         * Gönderim uç noktaları. Testte Http::fake bu adresleri taklit eder; sabit olarak
         * gömülmek yerine burada durmaları, fake'in tek doğru yerden okunmasını sağlar.
         */
        'token_url' => 'https://oauth2.googleapis.com/token',
        'gonderim_url' => 'https://fcm.googleapis.com/v1/projects/{proje}/messages:send',

        /*
         * Erişim jetonu ömrü 3600 sn'dir; 300 sn emniyet payıyla önbelleklenir. Pay olmasaydı
         * saniyeler kala alınan jeton FCM'e vardığında ölmüş olabilirdi (401 → boşa giden
         * gönderim). Önbellek anahtarı hizmet hesabının parmak iziyle damgalıdır: anahtar
         * döndürüldüğünde eski jeton kendiliğinden düşer.
         */
        'jeton_onbellek_sn' => 3300,
    ],

];
