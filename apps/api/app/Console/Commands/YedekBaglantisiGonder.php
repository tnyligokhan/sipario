<?php

namespace App\Console\Commands;

use App\Mail\YedekHazir;
use App\Yedek\YedekArsivi;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Mail;

/**
 * Günlük yedek bildirimi — en yeni yedeğin İNDİRME BAĞLANTISINI e-postayla yollar.
 *
 * NEDEN BU KOMUT VAR: yedekler aylardır alınıyordu ama yalnız sunucunun kendi diskinde
 * duruyordu; sunucu ölse yedek de onunla ölecekti. Makine dışına çıkarmanın "doğru" yolu
 * S3/uzak depodur ve o karar ertelendi (`DECISIONS.md`, 2026-08-15) — bu komut arada
 * kalan boşluğu insanla kapatır: her sabah bir bağlantı gelir, indiren kişi yedeği
 * makine dışına kendi taşır.
 *
 * ⚠️ BU KOMUT SESSİZ BAŞARISIZLIK ÜRETMEZ. Yedek yoksa, adres tanımsızsa ya da dosya
 * bayatsa çıkış kodu HATA olur ve gerekçe log'a yazılır. Zamanlanmış bir görevin en
 * tehlikeli hâli, hiçbir şey yapmadan başarıyla dönmesidir: bu depoda parola sıfırlama
 * postası tam olarak öyle aylarca hiçbir yere gitmedi.
 */
class YedekBaglantisiGonder extends Command
{
    protected $signature = 'yedek:baglanti-gonder';

    protected $description = 'En yeni veritabanı yedeğinin indirme bağlantısını e-posta ile gönderir';

    public function handle(): int
    {
        $adres = trim((string) config('yedek.eposta'));

        if ($adres === '') {
            $this->error('YEDEK_EPOSTA tanımsız — bildirim gönderilmedi.');

            return self::FAILURE;
        }

        $son = YedekArsivi::varsayilan()->sonYedek();

        if ($son === null) {
            $this->error('Arşivde yedek bulunamadı ('.config('yedek.dizin').') — bildirim gönderilmedi.');

            return self::FAILURE;
        }

        $tazelikSaat = max(1, (int) config('yedek.tazelik_saat', 30));
        // `(int)` şart: Carbon 3'te `diffInHours` KESİRLİ döner ve postada "3.7 saat önce"
        // gibi bir metin, sağlık raporu olmaktan çok gürültü olur.
        $yas = (int) $son['zaman']->diffInHours(now('Europe/Istanbul'));
        $bayat = $yas > $tazelikSaat;

        Mail::to($adres)->send(new YedekHazir(
            indirmeUrl: route('panel.yedek.indir', ['dosya' => $son['ad']]),
            satirlar: [
                'Dosya' => $son['ad'],
                'Boyut' => $this->boyut($son['boyut']),
                'Alındığı zaman' => $son['zaman']->translatedFormat('j F Y, H:i'),
            ],
            geriYuklemeKomutu: $this->geriYuklemeKomutu($son['ad']),
            tarihEtiketi: $son['zaman']->translatedFormat('j F Y'),
            bayat: $bayat,
            bayatUyarisi: $bayat
                ? 'Bu yedek '.$yas.' saat önce alınmış. Beklenen aralık '.$tazelikSaat.' saatin altıdır — yedekleme servisi durmuş olabilir.'
                : '',
        ));

        $this->info('Yedek bildirimi kuyruğa alındı: '.$son['ad'].' → '.$adres);

        if ($bayat) {
            $this->warn('Yedek bayat: '.$yas.' saat önce alınmış.');
        }

        return self::SUCCESS;
    }

    /**
     * Boyutu insanın okuyacağı biçime çevirir.
     *
     * Neden gerekli: `filesize` bayt döndürür ve e-postada "41233920" yazan bir satır,
     * okuyucuya yedeğin makul boyutta olup olmadığını SÖYLEMEZ. Boyut bu postadaki en
     * işlevsel sağlık göstergesidir — bir gün 12 KB'lık bir yedek gelirse (boş dump)
     * bunu ancak okunabilir bir sayı ele verir.
     */
    private function boyut(int $bayt): string
    {
        if ($bayt < 1024) {
            return $bayt.' B';
        }

        $birimler = ['KB', 'MB', 'GB'];
        $deger = $bayt / 1024;
        $i = 0;

        while ($deger >= 1024 && $i < count($birimler) - 1) {
            $deger /= 1024;
            $i++;
        }

        return number_format($deger, $deger < 10 ? 1 : 0, ',', '.').' '.$birimler[$i];
    }

    /**
     * Postada gösterilen geri yükleme komutu.
     *
     * BORU (`|`) KULLANILDI, süreç ikamesi (`<(...)`) DEĞİL: ikincisi yalnız bash'te
     * çalışır ve bu satırı kopyalayacak kişi Windows'ta PowerShell'de olabilir. Boru
     * her kabukta aynı işi görür.
     */
    private function geriYuklemeKomutu(string $ad): string
    {
        return 'gunzip -c '.$ad.' | docker compose exec -T db psql -U '
            .config('yedek.geri_yukleme_rolu').' -d '.config('yedek.veritabani');
    }
}
