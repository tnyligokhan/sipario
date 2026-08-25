<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

/**
 * ROL PAROLASI EŞİTLEME SÖZLEŞMESİ — "parolayı değiştirmek rolü de değiştirmeli".
 *
 * 2026-08-10'da üretim ~1 saat kapalı kaldı ve sebep tek cümleyle şuydu: `DB_PASSWORD`
 * döndürüldü, ama rolün parolası değişmedi. Çünkü rolleri kuran betik
 * (`docker/postgres/init/10-roles.sh`) PostgreSQL tarafından YALNIZ boş veri dizininde
 * koşturulur; hacim doluyken bir daha hiç koşmaz. Uygulama yeni anahtarla eski kilidi
 * açmaya çalıştı, `queue` "password authentication failed" ile çöktü, Coolify 10. yeniden
 * başlatmada uygulamayı durdurdu, temizlik `external` ağı sildi ve sonraki her deploy
 * "network declared as external, but could not be found" ile öldü.
 *
 * Bu dosya, düzeltmenin BAĞLI olduğunu kaynaktan denetler. Kasıtlı olarak veritabanı
 * açmaz: kanıtlamak istediği şey davranış değil, MEKANİZMANIN AĞACA BAĞLI OLMASIDIR —
 * bu depoda daha önce "tanımlı ama hiçbir yere bağlı değil" deseni beş kez doğdu
 * (`PushOzeti.beklemede`, güncelleme bandının kill-switch'i, `${LOG_CHANNEL:-stderr}`…).
 */
class RolParolaEsitlemeTest extends TestCase
{
    /** Uygulamanın bağlandığı parola değişkeni → o parolanın ait olduğu rol. */
    private const ROL_DEGISKENLERI = [
        'DB_PASSWORD' => 'sipario_app',
        'DB_PANEL_PASSWORD' => 'sipario_panel',
        'DB_OWNER_PASSWORD' => 'sipario_owner',
    ];

    /**
     * Aynı sırrın ikinci adları. Hepsi bir zamanlar gerçekten vardı ve tam da bu yüzden
     * ayrışabildiler: panelde biri güncellenip diğeri eski kaldığında fark, ancak üretim
     * çöktüğünde görülüyordu.
     */
    private const YASAKLI_TAKMA_ADLAR = [
        'SIPARIO_APP_PASSWORD',
        'SIPARIO_PANEL_PASSWORD',
        'DB_APP_PASSWORD',
    ];

    /**
     * Depo kökü, dosyanın KENDİ konumundan hesaplanır (`base_path()` DEĞİL): bu test
     * Laravel önyüklemesi yapmaz, çünkü denetlediği şey uygulama davranışı değil
     * depodaki dosyaların birbirine bağlılığıdır. Önyükleme bağımlılığı, testi tam da
     * yapılandırma bozukken çalışamaz hâle getirirdi.
     * apps/api/tests/Feature/Api → 5 üst dizin → depo kökü.
     */
    private function depoKoku(): string
    {
        return dirname(__DIR__, 5);
    }

    private function oku(string $goreliYol): string
    {
        $yol = $this->depoKoku().'/'.$goreliYol;
        $this->assertFileExists($yol, "Beklenen dosya yok: $goreliYol");

        return (string) file_get_contents($yol);
    }

    #[Test]
    public function rol_betigi_her_rol_icin_parolayi_yeniden_atar(): void
    {
        $betik = $this->oku('docker/postgres/init/10-roles.sh');

        foreach (self::ROL_DEGISKENLERI as $degisken => $rol) {
            $this->assertStringContainsString(
                $degisken,
                $betik,
                "10-roles.sh, uygulamanın bağlandığı $degisken değişkenini okumuyor — ".
                'rol başka bir sırla kurulursa ikisi ayrışır.'
            );
        }

        // ALTER, CREATE'ten ayrı ve KOŞULSUZ olmalı: rol zaten varken de parola env'deki
        // değere çekilmeli. Yalnız "IF NOT EXISTS ... CREATE" olsaydı, döndürülen parola
        // mevcut role hiç uygulanmaz ve arıza birebir tekrarlanırdı.
        foreach (['sipario_app', 'sipario_panel'] as $rol) {
            $this->assertMatchesRegularExpression(
                '/ALTER\s+ROLE\s+'.preg_quote($rol, '/').'\s+WITH\s+PASSWORD/i',
                $betik,
                "10-roles.sh içinde $rol için koşulsuz bir ALTER ROLE ... WITH PASSWORD yok."
            );
        }

        // Owner rolü adı POSTGRES_USER'dan gelir, sabit yazılmaz.
        $this->assertMatchesRegularExpression(
            '/ALTER\s+ROLE\s+:"owner_role"\s+WITH\s+PASSWORD/i',
            $betik,
            'Owner rolünün parolası hizalanmıyor — owner bayatlarsa migration ve yedekleme düşer.'
        );
    }

    #[Test]
    public function esitleyici_her_acilista_kosacak_sekilde_bagli(): void
    {
        $dockerfile = $this->oku('docker/postgres/Dockerfile');
        $sarmalayici = $this->oku('docker/postgres/sipario-entrypoint.sh');
        $esitleyici = $this->oku('docker/postgres/sipario-rol-esitle.sh');

        $this->assertStringContainsString(
            'sipario-rol-esitle.sh',
            $dockerfile,
            'Eşitleyici imaja kopyalanmıyor.'
        );
        $this->assertStringContainsString(
            'ENTRYPOINT ["/usr/local/bin/sipario-entrypoint.sh"]',
            $dockerfile,
            'ENTRYPOINT sarmalayıcıya çevrilmemiş — eşitleyici imajda DURUR ama hiç koşmaz. '.
            'Bu, bu depoda daha önce beş kez görülen "tanımlı ama bağlı değil" desenidir.'
        );
        $this->assertStringContainsString(
            '/usr/local/bin/sipario-rol-esitle.sh',
            $sarmalayici,
            'Sarmalayıcı eşitleyiciyi başlatmıyor.'
        );
        $this->assertStringContainsString(
            'exec docker-entrypoint.sh',
            $sarmalayici,
            'postgres `exec` ile devralınmıyor — PID 1 kabuk kalır ve SIGTERM postgres\'e ulaşmaz.'
        );
        $this->assertStringContainsString(
            '10-roles.sh',
            $esitleyici,
            'Eşitleyici rol betiğini çağırmıyor.'
        );
    }

    #[Test]
    public function compose_dosyalari_db_servisine_uygulamanin_degiskenlerini_gecirir(): void
    {
        foreach (['docker-compose.prod.yml', 'docker-compose.yml'] as $dosya) {
            $icerik = $this->oku($dosya);

            foreach (array_keys(self::ROL_DEGISKENLERI) as $degisken) {
                $this->assertMatchesRegularExpression(
                    '/^\s*'.preg_quote($degisken, '/').':/m',
                    $icerik,
                    "$dosya, db servisine $degisken geçirmiyor — rol o parolayla kurulamaz."
                );
            }
        }
    }

    /**
     * Yorum satırlarını atar. Yasaklı adları ararken bu şart: bu depoda kararların
     * GEREKÇESİ yorumlarda yaşıyor ve "eskiden şu ad vardı, kaldırıldı" cümlesini yazmak
     * testi kırmamalı. Denetlenen şey prose değil, yürürlükteki yapılandırmadır.
     * Yalnız tam satır yorumları atılır; değer içinde geçen `#` korunur.
     */
    private function yorumsuz(string $icerik): string
    {
        $satirlar = preg_split('/\R/', $icerik) ?: [];

        return implode("\n", array_filter(
            $satirlar,
            static fn (string $satir): bool => ! str_starts_with(ltrim($satir), '#')
        ));
    }

    #[Test]
    public function ayni_sir_icin_ikinci_bir_ad_yok(): void
    {
        $dosyalar = [
            'docker-compose.prod.yml',
            'docker-compose.yml',
            'docker/postgres/init/10-roles.sh',
            'docker/postgres/Dockerfile',
        ];

        foreach ($dosyalar as $dosya) {
            $icerik = $this->yorumsuz($this->oku($dosya));

            foreach (self::YASAKLI_TAKMA_ADLAR as $takmaAd) {
                $this->assertStringNotContainsString(
                    $takmaAd,
                    $icerik,
                    "$dosya içinde $takmaAd geçiyor. Aynı sırrın iki adı olduğunda biri ".
                    'güncellenip diğeri eski kalabilir ve fark yalnız üretimde görünür — '.
                    '2026-08-10 kesintisinin teşhisini saatlerce geciktiren tam olarak buydu.'
                );
            }
        }
    }
}
