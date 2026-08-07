<?php

namespace App\Support\Geocoding;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * KADEMELİ sorgu (kullanıcı kararı 2026-07-29, ikinci tur): her sorgu önce GOOGLE'a gider;
 * YANDEX yalnız Google kapıyı bulamadığında devreye girer. Sonuçlar BİRLEŞTİRİLMEZ — her aday
 * kendi sağlayıcısının etiketiyle ayrı satır olarak döner ve doğrusunu KULLANICI seçer.
 *
 * İlk tasarım (CokluGeocoder) ikisini her sorguda sorup yakın adayları tek satırda
 * birleştiriyordu; kullanıcı iki gerekçeyle geri çevirdi:
 *
 * 1. **Birleştirme seçimi gizliyor.** İstenen şey "iki servis ne buldu, yan yana göster,
 *    ben karar vereyim" — mutabakat rozeti değil. Ölçüm de destekledi: üç gerçek adreste
 *    25 m mutabakat HİÇ oluşmadı, birleştirme pratikte zaten çalışmıyordu.
 * 2. **Kotalar simetrik değil.** Yandex GÜNDE 1000 sorguyla sınırlı ve bu havuz TÜM bayilerin
 *    ortak malı — yüz aktif kullanıcı her sorguda Yandex'i de tetikleseydi havuz öğlen biterdi.
 *    Google'ın ücretsiz kademesi çok daha geniş; o yüzden ilk kurşunu hep Google atar,
 *    Yandex yalnız GEREKTİĞİNDE (Google kapıyı bulamadığında) ve günlük tavana kadar konuşur.
 *
 * Tavan dolunca ya da Yandex arızalanınca özellik DÜŞMEZ: Google'ın bulabildiği döner, sebep
 * log'a yazılır. 503 ancak hiçbir sağlayıcı cevap veremezse verilir. Aynı adresin ikinci
 * sorgusu controller önbelleğinden döner (30 gün, global) — kota yalnız İLK soruşta yanar.
 */
final class KademeliGeocoder implements Geocoder
{
    public function __construct(
        private readonly Geocoder $google,
        private readonly Geocoder $yandex,
        private readonly int $yandexGunlukTavan,
    ) {}

    public function hazirMi(): bool
    {
        return $this->google->hazirMi() || $this->yandex->hazirMi();
    }

    /**
     * Dönen liste her sağlayıcıdan EN FAZLA [$enFazla] aday içerir (Google önce, sonra Yandex);
     * toplamda kırpılmaz — Yandex'in adayını "liste doldu" diye atmak, onu çağırma sebebimizi
     * çöpe atmak olurdu.
     *
     * @return list<GeoAday>
     */
    public function ara(string $sorgu, int $enFazla): array
    {
        if (! $this->hazirMi()) {
            throw GeocodingException::yapilandirilmamis();
        }

        $adaylar = [];
        $ilkAriza = null;
        $cevapVar = false; // en az bir sağlayıcı istisnasız cevap verdi (BOŞ liste de cevaptır)

        if ($this->google->hazirMi()) {
            try {
                $adaylar = $this->etiketle($this->google->ara($sorgu, $enFazla), GeoAday::KAYNAK_GOOGLE);
                $cevapVar = true;
            } catch (GeocodingException $e) {
                Log::warning('Kademeli geocoder: google dustu', ['sebep' => $e->getMessage()]);
                $ilkAriza = $e;
            }
        }

        if ($this->yandexGerekli($adaylar, $cevapVar) && $this->yandex->hazirMi() && $this->butceVar()) {
            try {
                $adaylar = array_merge(
                    $adaylar,
                    $this->etiketle($this->yandex->ara($sorgu, $enFazla), GeoAday::KAYNAK_YANDEX)
                );
                $cevapVar = true;
            } catch (GeocodingException $e) {
                Log::warning('Kademeli geocoder: yandex dustu', ['sebep' => $e->getMessage()]);
                $ilkAriza ??= $e;
            }
        }

        // Hiçbir sağlayıcı cevap veremediyse bu bir ARIZADIR; boş liste dönmek "bu adres yok"
        // demek olurdu ve kullanıcı var olan adresi düzeltmeye çalışarak vakit kaybederdi.
        if (! $cevapVar) {
            throw $ilkAriza ?? GeocodingException::reddedildi();
        }

        return $adaylar;
    }

    /**
     * Yandex'in kotasını harcamaya değer mi? Google BİNA kesinliğinde en az bir aday verdiyse
     * hayır — kapı bulundu, ikinci görüşe gerek yok. Google hiç cevap veremediyse (anahtarsız
     * ya da arızalı), boş döndüyse ya da yalnız sokak/semt bulduysa evet: kotanın tam da
     * bunun için saklandığı durum budur.
     *
     * Bilinen bedel (kullanıcıyla konuşuldu): Google YANLIŞ binayı gösterirse kademe hiç
     * tetiklenmez ve Yandex'in muhtemelen doğru adayı görünmez. Kota gerçeği karşısında
     * kabul edilen risktir; önbellek + tavan koruması olmadan tersi sürdürülemezdi.
     *
     * @param  list<GeoAday>  $googleAdaylari
     */
    private function yandexGerekli(array $googleAdaylari, bool $googleCevapVerdi): bool
    {
        if (! $googleCevapVerdi) {
            return true;
        }

        foreach ($googleAdaylari as $aday) {
            if ($aday->kesinlik === GeoAday::KESINLIK_BINA) {
                return false;
            }
        }

        return true;
    }

    /**
     * Yandex'in GLOBAL günlük bütçesi (kiracı başına değil — 1000/gün limiti sağlayıcı
     * hesabının tamamına aittir, bayilere bölüştürmek kimseyi kurtarmaz). Sayaç önbellekte
     * yaşar ve yalnız GERÇEK Yandex çağrılarında artar; controller önbelleğinden dönen
     * cevaplar buraya hiç uğramaz.
     *
     * Sayaç ÇAĞRIDAN ÖNCE artırılır (rezervasyon): önce çağırıp sonra saysaydık eşzamanlı
     * istekler tavanı hep birlikte aşardı. Tavanı aşan artışlar çağrıya dönüşmediği için
     * sayacın şişmesi zararsızdır. Tavan 0 ya da negatifse sınırsız demektir.
     */
    private function butceVar(): bool
    {
        if ($this->yandexGunlukTavan <= 0) {
            return true;
        }

        $anahtar = 'geo:yandex:gun:'.now()->format('Y-m-d');
        Cache::add($anahtar, 0, now()->addDays(2));
        $kullanim = (int) Cache::increment($anahtar);

        if ($kullanim > $this->yandexGunlukTavan) {
            Log::warning('Kademeli geocoder: yandex gunluk tavani doldu', [
                'tavan' => $this->yandexGunlukTavan,
            ]);

            return false;
        }

        return true;
    }

    /**
     * @param  list<GeoAday>  $adaylar
     * @return list<GeoAday>
     */
    private function etiketle(array $adaylar, string $ad): array
    {
        return array_map(
            fn (GeoAday $a) => new GeoAday($a->metin, $a->lat, $a->lng, $a->kesinlik, $ad),
            $adaylar
        );
    }
}
