<?php

namespace App\Console\Commands;

use App\Bildirim\SurumDuyurucu;
use Illuminate\Console\Command;

/** Yeni sürüm yayınlandıysa telefonlara dürtü gönderir; gerekçe `SurumDuyurucu`da. */
class SurumDuyur extends Command
{
    protected $signature = 'surum:duyur';

    protected $description = 'Yayındaki sürümü denetler, yeniyse telefonlara bildirim gönderir';

    public function handle(SurumDuyurucu $duyurucu): int
    {
        $yapim = $duyurucu->denetle();
        $this->info($yapim === null ? 'Yeni sürüm yok.' : "Yapım {$yapim} duyuruldu.");

        return self::SUCCESS;
    }
}
