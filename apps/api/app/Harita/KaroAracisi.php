<?php

namespace App\Harita;

use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * CARTO KARO ARACISI — anahtarı ekler, sonucu diskte önbellekler (2026-09-26).
 *
 * Durum (anahtar, önbellek süresi, disk) ve davranış (getir/önbellekle/filigranı ayıkla) tek
 * nesnededir; denetleyici yalnız girdiyi doğrular ve cevabı yazar.
 *
 * ⚠️ FİLİGRAN ÖNBELLEĞE GİRMEZ: CARTO geçersiz/eksik anahtarda 200 + "API KEY REQUIRED" görseli
 * döner. Onu önbelleğe almak, anahtar düzeltildikten sonra da 30 gün boyunca aynı yazıyı
 * göstermek olurdu. Ayırt edici işaret ETag'in `wm-` önekidir (ölçüldü).
 */
final class KaroAracisi
{
    /** İzin verilen stiller — Positron (açık) ve Dark Matter (koyu). */
    public const STILLER = ['light_all', 'dark_all'];

    private readonly Filesystem $disk;

    public function __construct(
        private readonly ?string $anahtar,
        private readonly int $onbellekGun,
        private readonly int $zamanAsimi,
        ?Filesystem $disk = null,
    ) {
        $this->disk = $disk ?? Storage::disk('local');
    }

    public static function yapilandirmadan(): self
    {
        $anahtar = config('harita.carto_key');

        return new self(
            is_string($anahtar) && $anahtar !== '' ? $anahtar : null,
            max(1, (int) config('harita.onbellek_gun', 30)),
            max(1, (int) config('harita.timeout', 6)),
        );
    }

    /**
     * Karonun PNG baytları; alınamazsa null (anahtar yok, filigran, ağ hatası).
     */
    public function karo(string $stil, int $z, int $x, int $y, bool $retina): ?string
    {
        $yol = sprintf('harita-karo/%s/%d/%d/%d%s.png', $stil, $z, $x, $y, $retina ? '@2x' : '');

        if ($this->disk->exists($yol) && $this->taze($yol)) {
            return $this->disk->get($yol);
        }

        $baytlar = $this->indir($stil, $z, $x, $y, $retina);
        if ($baytlar !== null) {
            $this->disk->put($yol, $baytlar);
        }

        return $baytlar;
    }

    private function taze(string $yol): bool
    {
        return $this->disk->lastModified($yol) >= now()->subDays($this->onbellekGun)->getTimestamp();
    }

    private function indir(string $stil, int $z, int $x, int $y, bool $retina): ?string
    {
        if ($this->anahtar === null) {
            return null;
        }

        // CARTO'nun a–d alt alan adları — yük dağılsın diye karo koordinatına göre seçilir.
        $alt = ['a', 'b', 'c', 'd'][($x + $y) % 4];
        $adres = sprintf(
            'https://%s.basemaps.cartocdn.com/%s/%d/%d/%d%s.png',
            $alt, $stil, $z, $x, $y, $retina ? '@2x' : '',
        );

        try {
            $yanit = Http::timeout($this->zamanAsimi)
                ->withQueryParameters(['key' => $this->anahtar])
                ->get($adres);
        } catch (ConnectionException) {
            return null;
        }

        if (! $yanit->successful()) {
            return null;
        }
        if (str_starts_with(trim((string) $yanit->header('ETag'), '"'), 'wm-')) {
            // Anahtar reddedildi/eksik: CARTO filigran döndü. Log'a düşer, önbelleğe DÜŞMEZ.
            Log::warning('CARTO karo anahtarı reddedildi (filigran döndü)', ['stil' => $stil]);

            return null;
        }

        return $yanit->body();
    }
}
