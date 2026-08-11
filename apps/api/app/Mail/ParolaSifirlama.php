<?php

namespace App\Mail;

/**
 * PAROLA SIFIRLAMA BAĞLANTISI.
 *
 * BUNUN YERİNE GEÇTİĞİ ŞEY: Laravel'in kendi `ResetPassword` bildirimi — ve o bildirim bu
 * projede **İngilizce basıyordu**. Sebep ölçüldü: `.env`de `APP_LOCALE=tr` yazıyor ama depoda
 * `lang/tr` dizini YOK, dolayısıyla `__('Reset Password')` gibi anahtarlar çeviri bulamayıp
 * anahtarın kendisine (İngilizce) düşüyordu. Yani Türkçe bir üründe, hesabını kurtarmaya çalışan
 * esnafa "Hello! You are receiving this email because we received a password reset request"
 * gidiyordu. Bu şablon o yolu tamamen kapatır; çeviri dosyasına da bağımlı değildir.
 *
 * GÜVENLİK METNİ SÜS DEĞİL: postayı isteyen kişi ile alan kişi AYNI OLMAYABİLİR (birisi
 * başkasının adresini yazmış olabilir). Bu yüzden "siz istemediyseniz" cümlesi zorunludur ve
 * eylemsizliğin güvenli olduğunu söyler — bağlantı kullanılmazsa hiçbir şey değişmez.
 *
 * SÜRE YAZILIR: `config('auth.passwords.users.expire')` dakikadır. "Bağlantı bir süre sonra
 * geçersiz olur" demek, süre dolduğunda kullanıcıya arızalı bir ürün izlenimi verir; kaç dakika
 * olduğunu söylemek beklentiyi doğru kurar.
 */
class ParolaSifirlama extends SiparioPostasi
{
    public function __construct(
        public readonly string $yetkili,
        public readonly string $url,
        public readonly int $gecerlilikDakika,
    ) {}

    protected function sablon(): string
    {
        return 'parola-sifirlama';
    }

    protected function konu(): string
    {
        return 'Sipario parolanızı sıfırlayın';
    }

    protected function onizleme(): string
    {
        return 'Bağlantı '.$this->gecerlilikDakika.' dakika geçerli. Siz istemediyseniz bu iletiyi yok sayın.';
    }
}
