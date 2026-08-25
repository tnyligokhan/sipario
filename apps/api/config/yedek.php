<?php

return [

    /*
     * Yedek dosyalarının bulunduğu dizin — `backup` sidecar'ının yazdığı volume.
     *
     * `docker-compose.prod.yml`de `sipario_backups` volume'ü `app` ve `scheduler`
     * servislerine SALT-OKUNUR (`:ro`) bağlanır. Salt-okunur olması biçimsel değil:
     * yedeği ÜRETEN tek yer sidecar'dır ve uygulama tarafından silinebilen bir yedek,
     * yedek sayılmaz.
     */
    'dizin' => env('YEDEK_DIZIN', '/backups'),

    /*
     * Günlük yedek bildiriminin gideceği adres.
     *
     * BOŞSA GÖNDERİM YAPILMAZ ve komut bunu AÇIKÇA söyleyerek çıkar — sessizce
     * "başarılı" dönmez. Bu depoda sessiz hiçliğin bedeli birkaç kez ölçüldü
     * (parola sıfırlama postası aylarca `log` sürücüsüne akmıştı).
     */
    'eposta' => env('YEDEK_EPOSTA', ''),

    /*
     * Yedeğin ne kadar süredir tazelenmediği "eski" sayılır (saat).
     *
     * Sidecar 24 saatte bir yazar; 30 saat, normal bir gecikmeyi alarma çevirmeyecek
     * kadar geniş, iki günü kaçırmayacak kadar dar. Eşiği aşan yedek e-postada
     * UYARI bandıyla gider — "yedek geldi" diye bakıp aslında dünkü dosyayı indirmek,
     * yedeği olduğunu sanmanın en pahalı biçimidir.
     */
    'tazelik_saat' => (int) env('YEDEK_TAZELIK_SAAT', 30),

    /*
     * Geri yükleme komutunda görünecek rol ve veritabanı adı.
     *
     * SABİT YAZILMADI, ORTAMDAN OKUNUR — `PLAN.md` 15. maddenin dersi: bir iş değeri
     * (rol adı, veritabanı adı) koda elle yazıldığında, o değer değiştiği gün metin
     * sessizce yanlışa döner ve kimse fark etmez. Burada yanlış bir komut, gece yarısı
     * veri geri yüklemeye çalışan kişiyi yanıltır.
     *
     * `sipario_owner` seçildi, `sipario_app` DEĞİL: geri yükleme şema düşürüp yeniden
     * kurar (`pg_dump --clean --if-exists`) ve uygulama rolünün buna yetkisi yoktur.
     */
    'veritabani' => env('DB_DATABASE', 'sipario'),
    'geri_yukleme_rolu' => env('DB_OWNER_USERNAME', 'sipario_owner'),

];
