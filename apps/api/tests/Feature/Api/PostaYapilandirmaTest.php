<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

/**
 * POSTA YAPILANDIRMA SÖZLEŞMESİ — "config'in OKUDUĞU her anahtar container'a GİRMELİ".
 *
 * 2026-08-11'de ölçüldü: `docker-compose.prod.yml` `MAIL_ENCRYPTION` geçiriyordu ama
 * `config/mail.php` öyle bir anahtarı HİÇ okumuyor — Laravel'in bu sürümünde
 * `MailManager::createSmtpTransport` şemayı yalnız porttan türetiyor. Aynı anda `MAIL_SCHEME`
 * (gerçekten okunan anahtar) compose'da HİÇ GEÇMİYORDU, yani panele yazılsa bile container'a
 * ulaşamıyordu.
 *
 * İki kusur da SESSİZDİR ve zararları simetriktir:
 *   • Ölü anahtar: kullanıcı hiçbir şey yapmayan bir düğmeyi çevirir ve yapılandırmayı
 *     TAMAMLANMIŞ sanır — arızadan kötüdür, çünkü yanlış bir "ayarlandı" hissi verir.
 *   • Eksik anahtar: kullanıcı doğru düğmeyi çevirir ve hiçbir etkisi olmaz.
 *
 * Posta yolunun kendisi TASARIM GEREĞİ sessizdir (`Parola.php` numaralandırmayı önlemek için
 * hatayı ekrana yansıtmaz — DECISIONS 2026-08-09), yani bu iki kusur kullanıcıya asla bir hata
 * olarak görünmez. Bu yüzden bağ makineyle zorlanıyor: "dosyada ne yazıyor" ile "container'a
 * ne gidiyor" ayrı sorulardır ve yalnız ikincisi postayı gönderir.
 *
 * Kaynak seviyesindedir çünkü kanıtladığı şey davranış değil, BAĞIN VARLIĞIDIR.
 */
class PostaYapilandirmaTest extends TestCase
{
    /**
     * `config/mail.php`in smtp bloğunun okuduğu, dağıtımda DIŞARIDAN verilmesi gereken anahtarlar.
     *
     * `MAIL_LOG_CHANNEL` ve `MAIL_SENDMAIL_PATH` bilerek YOK: ilki `log` sürücüsüne, ikincisi
     * `sendmail`e ait ve ikisi de bu dağıtımda kullanılmıyor.
     */
    private const GEREKLI_ANAHTARLAR = [
        'MAIL_MAILER',
        'MAIL_SCHEME',
        'MAIL_URL',
        'MAIL_HOST',
        'MAIL_PORT',
        'MAIL_USERNAME',
        'MAIL_PASSWORD',
        'MAIL_EHLO_DOMAIN',
        'MAIL_FROM_ADDRESS',
        'MAIL_FROM_NAME',
    ];

    private function compose(): string
    {
        $yol = dirname(__DIR__, 5).'/docker-compose.prod.yml';
        $this->assertFileExists($yol);

        // Satır sonları normalize edilir — dosya CRLF ile duruyor (bkz. DeploySirasiTest).
        return str_replace(["\r\n", "\r"], "\n", (string) file_get_contents($yol));
    }

    private function mailConfigKaynagi(): string
    {
        $yol = dirname(__DIR__, 3).'/config/mail.php';
        $this->assertFileExists($yol);

        return (string) file_get_contents($yol);
    }

    #[Test]
    public function config_in_okudugu_her_posta_anahtari_composeda_gecirilir(): void
    {
        $compose = $this->compose();

        foreach (self::GEREKLI_ANAHTARLAR as $anahtar) {
            $this->assertMatchesRegularExpression(
                '/^\s*'.preg_quote($anahtar, '/').':\s*\$\{'.preg_quote($anahtar, '/').'/m',
                $compose,
                "$anahtar `config/mail.php` tarafından okunuyor ama docker-compose.prod.yml "
                ."ONU CONTAINER'A GEÇİRMİYOR. Panele yazılsa bile ulaşmaz: Coolify'ın env "
                .'değişkenleri yalnız compose dosyasındaki ${...} yerlerine değer basar.',
            );
        }
    }

    #[Test]
    public function olu_anahtar_gecirilmez(): void
    {
        // `MAIL_ENCRYPTION` Laravel 11+'ta okunmuyor. Compose'a geri eklenirse bu test kırmızıya
        // döner ve ekleyen kişi, önce `config/mail.php`in onu gerçekten okuduğunu göstermek
        // zorunda kalır (aşağıdaki test o iddiayı kilitliyor).
        $this->assertStringNotContainsString(
            'MAIL_ENCRYPTION:',
            $this->compose(),
            'MAIL_ENCRYPTION ölü bir düğmedir — çevrilir, hiçbir şey olmaz, kullanıcı '
            .'yapılandırmayı tamamlanmış sanır.',
        );
    }

    #[Test]
    public function mail_config_encryption_okumuyor_scheme_okuyor(): void
    {
        // Yukarıdaki iki testin DAYANAĞI. Laravel bir gün `encryption`a geri dönerse bu test
        // kırılır ve `olu_anahtar_gecirilmez` yanlış bir şeyi savunuyor olmaktan kurtulur —
        // yoksa çerçeve değiştiğinde compose sessizce eksik kalırdı.
        $kaynak = $this->mailConfigKaynagi();

        $this->assertStringContainsString("env('MAIL_SCHEME')", $kaynak);
        $this->assertStringNotContainsString('MAIL_ENCRYPTION', $kaynak);
    }

    /**
     * BOŞ DİZE ≠ TANIMSIZ — postacının tamamını öldüren tuzak.
     *
     * 2026-08-11'de canlıda ÖLÇÜLDÜ: `MAIL_URL` boş dizeyle tanımlıyken `Mail::raw()`
     * `Unsupported mail transport []` fırlatıyordu; host/port/kullanıcı/parola sapasağlamdı.
     * Sebep `MailManager::getConfig()`: `isset($config['url'])` boş dizeyi de "set" sayıyor,
     * URL dalına giriyor ve `$config['transport'] = Arr::pull($config, 'driver')` ile
     * transport'u NULL'a düşürüyor.
     *
     * Bu test kaynağı denetler, davranışı değil: `env(...) ?: null` kalkarsa kırmızıya döner.
     * Değeri Coolify panelinden de boş tanımlanabildiği için kapı compose'da DEĞİL burada.
     */
    #[Test]
    public function bos_dize_null_a_cevrilir_yoksa_tek_bos_degisken_postaciyi_oldurur(): void
    {
        $kaynak = $this->mailConfigKaynagi();

        foreach (['MAIL_SCHEME', 'MAIL_URL'] as $anahtar) {
            $this->assertMatchesRegularExpression(
                "/env\\('".preg_quote($anahtar, '/')."'\\)\\s*\\?:\\s*null/",
                $kaynak,
                "$anahtar boş dizeyle tanımlandığında `null`a çevrilmeli. `MAIL_URL` için bu "
                .'pazarlıksız: boş bir URL `transport`u null yapar ve postacı tamamen ölür.',
            );
        }

        // `local_domain` ikinci argüman varsayılanı KULLANAMAZ: `env()` boş dizede varsayılana
        // düşmez, `''` döner ve EHLO adı boş gider.
        $this->assertMatchesRegularExpression(
            "/env\\('MAIL_EHLO_DOMAIN'\\)\\s*\\n?\\s*\\?:/",
            $kaynak,
            'MAIL_EHLO_DOMAIN boşsa APP_URL host\'una düşmeli; env() varsayılanı bunu yapmaz.',
        );
    }

    #[Test]
    public function posta_surucusunun_varsayilani_sessiz_log_oldugu_icin_composeda_yazili_durur(): void
    {
        // `MAIL_MAILER` tanımsızken posta `log`a gider ve KULLANICIYA HİÇBİR ŞEY GÖRÜNMEZ.
        // Varsayılanın compose'da açıkça yazılı olması, deploy eden kişinin onu görmesi içindir.
        $this->assertMatchesRegularExpression(
            '/^\s*MAIL_MAILER:\s*\$\{MAIL_MAILER:-log\}/m',
            $this->compose(),
        );
    }
}
