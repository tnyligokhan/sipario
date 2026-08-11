<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Mailer
    |--------------------------------------------------------------------------
    |
    | This option controls the default mailer that is used to send all email
    | messages unless another mailer is explicitly specified when sending
    | the message. All additional mailers can be configured within the
    | "mailers" array. Examples of each type of mailer are provided.
    |
    */

    'default' => env('MAIL_MAILER', 'log'),

    /*
    |--------------------------------------------------------------------------
    | Mailer Configurations
    |--------------------------------------------------------------------------
    |
    | Here you may configure all of the mailers used by your application plus
    | their respective settings. Several examples have been configured for
    | you and you are free to add your own as your application requires.
    |
    | Laravel supports a variety of mail "transport" drivers that can be used
    | when delivering an email. You may specify which one you're using for
    | your mailers below. You may also add additional mailers if needed.
    |
    | Supported: "smtp", "sendmail", "mailgun", "ses", "ses-v2",
    |            "postmark", "resend", "log", "array",
    |            "failover", "roundrobin"
    |
    */

    'mailers' => [

        'smtp' => [
            'transport' => 'smtp',

            /*
             * ⚠️ `?: null` ÜÇÜNDE DE ZORUNLUDUR — SÜS DEĞİL. (2026-08-11, canlıda ölçüldü.)
             *
             * `env('X')` tanımlı ama BOŞ bir değişkende `''` döner, `null` değil. Bu üç alanda
             * boş dize ile tanımsızlık AYNI ŞEY DEĞİLDİR ve farkı en pahalı ödeyen `url`dir:
             *
             *   MailManager::getConfig()
             *     if (isset($config['url'])) {                    // '' de "set" sayılır
             *         $config = array_merge($config, ...parseConfiguration($config));
             *         $config['transport'] = Arr::pull($config, 'driver');
             *     }
             *
             * Boş URL'de ayrıştırıcı hiçbir `driver` üretmez, `Arr::pull` null döner ve
             * `transport` NULL'a düşer → `Unsupported mail transport []`. Yani **BOŞ BIRAKILMIŞ
             * TEK BİR `MAIL_URL` DEĞİŞKENİ POSTACININ TAMAMINI ÖLDÜRÜR** — host, port, kullanıcı
             * ve parola sapasağlam dururken. Hata da kullanıcıya görünmez: bu projede gönderim
             * yolları numaralandırmayı önlemek için istisnayı yutuyor (DECISIONS 2026-08-09).
             *
             * `local_domain` aynı sınıftan, sessiz bir zarar verir: `env()` `''` döndürdüğü an
             * ikinci argümandaki `APP_URL` VARSAYILANI HİÇ KULLANILMAZ ve EHLO adı boş gider —
             * bazı sunucular böyle bir istemciyi reddeder.
             *
             * Düzeltme burada, tek noktada yapılır ve compose'da değil: değişken panelden de
             * boş tanımlanabilir, o yüzden kapının yeri yapılandırma dosyasıdır.
             */
            'scheme' => env('MAIL_SCHEME') ?: null,
            'url' => env('MAIL_URL') ?: null,
            'host' => env('MAIL_HOST', '127.0.0.1'),
            'port' => env('MAIL_PORT', 2525),
            'username' => env('MAIL_USERNAME'),
            'password' => env('MAIL_PASSWORD'),
            'timeout' => null,
            'local_domain' => env('MAIL_EHLO_DOMAIN')
                ?: parse_url((string) env('APP_URL', 'http://localhost'), PHP_URL_HOST),
        ],

        'ses' => [
            'transport' => 'ses',
        ],

        'postmark' => [
            'transport' => 'postmark',
            // 'message_stream_id' => env('POSTMARK_MESSAGE_STREAM_ID'),
            // 'client' => [
            //     'timeout' => 5,
            // ],
        ],

        'resend' => [
            'transport' => 'resend',
        ],

        'sendmail' => [
            'transport' => 'sendmail',
            'path' => env('MAIL_SENDMAIL_PATH', '/usr/sbin/sendmail -bs -i'),
        ],

        'log' => [
            'transport' => 'log',
            'channel' => env('MAIL_LOG_CHANNEL'),
        ],

        'array' => [
            'transport' => 'array',
        ],

        'failover' => [
            'transport' => 'failover',
            'mailers' => [
                'smtp',
                'log',
            ],
            'retry_after' => 60,
        ],

        'roundrobin' => [
            'transport' => 'roundrobin',
            'mailers' => [
                'ses',
                'postmark',
            ],
            'retry_after' => 60,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Global "From" Address
    |--------------------------------------------------------------------------
    |
    | You may wish for all emails sent by your application to be sent from
    | the same address. Here you may specify a name and address that is
    | used globally for all emails that are sent by your application.
    |
    */

    'from' => [
        'address' => env('MAIL_FROM_ADDRESS', 'hello@example.com'),
        'name' => env('MAIL_FROM_NAME', env('APP_NAME', 'Laravel')),
    ],

];
