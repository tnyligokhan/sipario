<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

/**
 * DEPLOY SIRASI SÖZLEŞMESİ — "hiçbir servis, tabloları yaratılmadan başlamaz".
 *
 * 2026-08-10/2'de dev sıfırdan kurulurken ÖLÇÜLDÜ: `queue` iki kez çöküp yeniden başladı,
 * sebebi `relation "cache" does not exist`ti. `queue` yalnız `db healthy` bekliyordu, oysa
 * tabloları yaratan migration Coolify'ın post-deployment adımında — yani yığın ayağa
 * KALKTIKTAN SONRA — koşuyordu.
 *
 * İki yeniden başlatma zararsız görünür. Değildir: Coolify'ın tavanı 10'dur ve bu sayı
 * MIGRATION SÜRESİNE bağlıdır. Tavan aşıldığında ne olduğu aynı gün ölçüldü —
 * `StopApplication` → `CleanupDocker` → `external` ağ silinir → sonraki HER deploy
 * "network declared as external, but could not be found" ile ölür ve panelden çıkış yolu
 * kalmaz. Üretimi bir saat kapatan zincirin ilk halkası buydu.
 *
 * Bu dosya, migration'ın ÖNKOŞUL olarak bağlı kaldığını denetler. Kaynak seviyesindedir
 * çünkü kanıtlamak istediği şey davranış değil, BAĞIN VARLIĞIDIR — bu depoda "tanımlı ama
 * bağlı değil" deseni altı kez doğdu.
 */
class DeploySirasiTest extends TestCase
{
    /** Migration bitmeden başlamaması gereken servisler. */
    private const ONKOSULLU_SERVISLER = ['app', 'queue', 'scheduler'];

    private function compose(): string
    {
        $yol = dirname(__DIR__, 5).'/docker-compose.prod.yml';
        $this->assertFileExists($yol);

        // Satır sonları normalize edilir: dosya CRLF ile duruyor ve `$` çapası satır sonundaki
        // `\r`i geçemediği için servis blokları hiç eşleşmiyordu — test, bağ KOPMADIĞI hâlde
        // "servis yok" diyerek kırmızı verirdi.
        return str_replace(["\r\n", "\r"], "\n", (string) file_get_contents($yol));
    }

    /**
     * Tek bir servisin bloğunu ayırır. Düz metin araması yetmez: "dosyada `migrate` geçiyor"
     * ile "`queue` gerçekten `migrate`'e bağlı" ayrı iddialardır ve yalnız ikincisi arızayı
     * önler. Blok, `  <ad>:` satırından bir sonraki iki boşluk girintili anahtara kadardır.
     */
    private function servisBloku(string $servis): string
    {
        $icerik = $this->compose();
        $desen = '/^  '.preg_quote($servis, '/').':$(.*?)(?=^  [a-z]|\z)/ms';

        $this->assertMatchesRegularExpression(
            $desen,
            $icerik,
            "docker-compose.prod.yml içinde `$servis` servisi yok."
        );
        preg_match($desen, $icerik, $eslesme);

        return $eslesme[1];
    }

    #[Test]
    public function migration_tek_atimlik_bir_servistir(): void
    {
        $blok = $this->servisBloku('migrate');

        $this->assertMatchesRegularExpression(
            '/entrypoint:.*artisan.*migrate.*--database=pgsql_owner.*--force/s',
            $blok,
            'migrate servisi migration komutunu koşmuyor.'
        );

        // `restart: "no"` PAZARLIKSIZ: yeniden başlatılan bir tek-atımlık servis hiçbir zaman
        // "tamamlandı" durumuna oturmaz ve `service_completed_successfully` bekleyen her servis
        // sonsuza kadar asılı kalır — yani deploy, düzeltmenin kendisi yüzünden kilitlenir.
        $this->assertMatchesRegularExpression(
            '/restart:\s*"no"/',
            $blok,
            'migrate servisinde `restart: "no"` yok — tek atımlık servis yeniden başlatılırsa '.
            'deploy `service_completed_successfully` beklerken sonsuza kadar asılır.'
        );

        $this->assertMatchesRegularExpression(
            '/db:\s*\n\s*condition:\s*service_healthy/',
            $blok,
            'migrate, db hazır olmadan koşuyor.'
        );
    }

    #[Test]
    public function uygulama_servisleri_migration_bitmeden_baslamaz(): void
    {
        foreach (self::ONKOSULLU_SERVISLER as $servis) {
            $blok = $this->servisBloku($servis);

            $this->assertMatchesRegularExpression(
                '/migrate:\s*\n\s*condition:\s*service_completed_successfully/',
                $blok,
                "`$servis` servisi migration'ı beklemiyor. Tablolar yaratılmadan başlarsa çöker, ".
                'docker yeniden başlatır ve Coolify 10. yeniden başlatmada bütün kaynağı '.
                'durdurup ağı siler — o noktadan sonra deploy düğmesinin çıkış yolu yoktur.'
            );
        }
    }

    #[Test]
    public function yedekleme_migrationa_baglanmaz(): void
    {
        $blok = $this->servisBloku('backup');

        // Bilinçli: migration düşerse yedekleme YİNE DE koşmalı. Kurtarma aracını arıza
        // anında kapatmak, ihtiyaç duyulan tek anda onu yok etmek demektir.
        $this->assertStringNotContainsString(
            'service_completed_successfully',
            $blok,
            'backup servisi migration\'a bağlanmış — migration düştüğünde yedekleme de durur.'
        );
    }
}
