<?php

namespace App\Bildirim;

use App\Jobs\YeniSurumGonderimi;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * YENİ SÜRÜM YAYINLANINCA TELEFONLARA HABER VERİR (kullanıcı isteği 2026-11-06).
 *
 * NEDEN SUNUCUDA: telefonun kontrolü uygulamanın içinde koşar, yani uygulama açılmadan bayinin
 * yeni sürümden haberi olmuyordu. Kapalı uygulamayı uyandırabilen tek şey FCM dürtüsüdür.
 *
 * NEDEN YOKLAMA, NEDEN CI'DAN ÇAĞRI DEĞİL: yayın `surum.json`u GitHub'a yükler ve telefonlar da
 * zaten oraya bakar. Sunucunun aynı dosyaya bakması yeni bir sır, yeni bir uç nokta ve yetkisiz
 * biri tarafından tetiklenebilecek "herkese bildirim gönder" yüzeyi açmaz. Bedeli en çok iki
 * dakikalık gecikmedir.
 *
 * İLK KOŞU GÖNDERMEZ, YALNIZ KAYDEDER: önbellek boşken görülen yapım yeni değildir, sunucunun
 * onu ilk kez görmesidir. Göndermek her temiz kurulumda bütün bayilere bildirim düşürürdü.
 *
 * KİMİN GÜNCELLEMESİ GEREKTİĞİNE BURADA KARAR VERİLMEZ: sunucu telefonun yapımını bilmez. Dürtü
 * herkese gider, güncel telefon ve mağaza derlemesi onu telefonda eler (`push_sozlesmesi.dart`).
 */
class SurumDuyurucu
{
    /** Duyurulan yapımı döner; yeni sürüm yoksa null. */
    public function denetle(): ?int
    {
        $kanal = (string) config('push.surum.kanal');
        $bilgi = $this->yayindakiSurum($kanal);

        if ($bilgi === null) {
            return null;
        }

        $anahtar = "surum_duyurusu:{$kanal}";
        $son = Cache::get($anahtar);

        if ($son !== null && $bilgi['yapim'] <= (int) $son) {
            return null;
        }

        Cache::forever($anahtar, $bilgi['yapim']);

        if ($son === null) {
            return null;
        }

        YeniSurumGonderimi::dispatch($bilgi['yapim'], $bilgi['surum']);
        Log::info('Yeni sürüm duyuruldu', ['kanal' => $kanal, 'yapim' => $bilgi['yapim']]);

        return $bilgi['yapim'];
    }

    /**
     * Yayındaki sürüm. Okunamazsa null: bir sonraki koşu yeniden dener.
     *
     * Adres her istekte değişir: düz adres yayından saatler sonra bile CDN'den eski içeriği
     * döndürüyordu (ölçüldü, bkz. `guncelleme_sozlesmesi.dart::onbelleksizAdres`).
     *
     * @return array{yapim: int, surum: string}|null
     */
    private function yayindakiSurum(string $kanal): ?array
    {
        $adres = str_replace('{kanal}', $kanal, (string) config('push.surum.adres'));

        try {
            $yanit = Http::timeout(10)->get($adres, ['t' => now()->timestamp]);
        } catch (ConnectionException $e) {
            Log::info('surum.json okunamadı', ['hata' => $e->getMessage()]);

            return null;
        }

        $yapim = $yanit->successful() ? $yanit->json('yapim') : null;
        $surum = $yanit->successful() ? $yanit->json('surum') : null;

        if (! is_numeric($yapim) || (int) $yapim <= 0 || ! is_string($surum) || $surum === '') {
            return null;
        }

        return ['yapim' => (int) $yapim, 'surum' => $surum];
    }
}
