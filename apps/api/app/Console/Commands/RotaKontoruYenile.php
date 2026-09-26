<?php

namespace App\Console\Commands;

use App\Abonelik\RotaKontoru;
use Illuminate\Console\Command;

/**
 * AY BAŞI OTO-SIRALAMA HAKKI YENİLEMESİ (kullanıcı kararı 2026-09-26).
 *
 * HER GÜN koşar, ay başına bir kez etki eder: yenileme `route_credits_renewed_on`a bakarak
 * idempotenttir. Günlük koşmanın sebebi telafidir — zamanlayıcı ayın 1'inde ayakta değilse
 * ertesi gün yine yeniler; "yalnız ayın 1'inde" kurulan bir iş o ayı sessizce atlardı.
 *
 * `pgsql_owner`: konsoldan koşar, RLS kiracı değişkeni KURULU DEĞİLDİR (AbonelikHatirlatmalari
 * ile aynı gerekçe) — normal bağlantı hiçbir satır görmez ve "0 bayi" der.
 */
class RotaKontoruYenile extends Command
{
    protected $signature = 'rota:aylik-yenile';

    protected $description = 'Oto-sıralama ücretsiz aylık hakkını ay başında yeniler (satın alınan hak korunur)';

    public function handle(): int
    {
        $adet = (new RotaKontoru('pgsql_owner'))->yenile();
        $this->info("{$adet} bayinin oto-sıralama hakkı yenilendi (dönem ".RotaKontoru::donemBasi().').');

        return self::SUCCESS;
    }
}
