<?php

namespace App\Jobs;

use App\Bildirim\PushGondericisi;
use App\Bildirim\PushOlayi;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Push gönderimi KUYRUKTAN koşar — istekten değil.
 *
 * SEBEP: gönderim iki dış HTTP turudur (Google'dan jeton + FCM'e mesaj) ve her biri saniyeler
 * sürebilir. Bunu senkron isteğinin içinde yapmak, kuryenin "teslim ettim" dokunuşunu ağ
 * gecikmesine bağlamak demektir; bu üründe teslim kapatma İNTERNETSİZ ve saniyeler içinde
 * bitmek zorundadır (BRIEF kırmızı çizgi #3). Bildirim asla bir iş akışını bekletemez.
 *
 * `afterCommit` ÇAĞIRAN TARAFTA VERİLİR: senkron olayları transaction içinde uygulanır ve
 * transaction geri alınırsa iş kuyruğa hiç girmemelidir — yoksa var olmayan bir siparişin
 * bildirimi telefonlara düşer.
 */
class PushGonderimi implements ShouldQueue
{
    use Queueable;

    /**
     * Üç deneme: geçici ağ arızası (FCM 5xx) gerçektir ama sonsuz denemenin anlamı yoktur —
     * bildirim GECİKİNCE değerini yitirir. `PushSonucu::Kalici` zaten yeniden denenmez;
     * bu sayı yalnız geçici arızalar içindir.
     */
    public int $tries = 3;

    public int $backoff = 10;

    public function __construct(
        public readonly string $tenantId,
        public readonly PushOlayi $olay,
        public readonly string $varlikId,
        public readonly ?string $aliciUserId = null,
        public readonly ?string $haricCihazId = null,
    ) {}

    public function handle(PushGondericisi $gonderici): void
    {
        $gonderici->gonder(
            $this->tenantId,
            $this->olay,
            $this->varlikId,
            $this->aliciUserId,
            $this->haricCihazId,
        );
    }
}
