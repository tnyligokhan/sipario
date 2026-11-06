<?php

namespace App\Jobs;

use App\Bildirim\PushGondericisi;
use App\Bildirim\PushOlayi;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Yeni sürüm dürtüsünü bütün cihazlara gönderir.
 *
 * Yeniden deneme zararsızdır: bildirim kimliği yapım numarasına bağlıdır ve telefonda ikinci dürtü
 * aynı satırın üzerine yazar.
 */
class YeniSurumGonderimi implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public int $backoff = 30;

    public function __construct(
        public readonly int $yapim,
        public readonly string $surum,
    ) {}

    public function handle(PushGondericisi $gonderici): void
    {
        $gonderici->herkese(PushOlayi::YeniSurum, (string) $this->yapim, ['surum' => $this->surum]);
    }
}
