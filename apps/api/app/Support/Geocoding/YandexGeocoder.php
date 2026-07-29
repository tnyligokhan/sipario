<?php

namespace App\Support\Geocoding;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Yandex Geocoder (HTTP API). Türkiye adreslerinde serbest metin ayrıştırması güçlüdür —
 * esnafın yazdığı "bahçelievler mah 5. sok no12 d3" gibi girdileri çözebilen az sayıda
 * servisten biri; ilk sağlayıcı olarak bu yüzden seçildi (DECISIONS).
 *
 * DİKKAT — `Point.pos` "BOYLAM ENLEM" sırasındadır (lng lat), coğrafyada alışılanın TERSİ.
 * Burada ters okunursa Antalya'daki bir adres Hindistan'a düşer ve rota sessizce saçmalar;
 * bu yüzden ayrıştırma tek yerde durur ve testle kilitlenir.
 */
final class YandexGeocoder implements Geocoder
{
    public function __construct(
        private readonly string $apiKey,
        private readonly string $baseUrl,
        private readonly int $timeout,
        private readonly string $lang,
        private readonly string $bbox,
    ) {}

    public function hazirMi(): bool
    {
        return $this->apiKey !== '';
    }

    /** @return list<GeoAday> */
    public function ara(string $sorgu, int $enFazla): array
    {
        if (! $this->hazirMi()) {
            throw GeocodingException::yapilandirilmamis();
        }

        $adaylar = $this->sor($sorgu, $enFazla);
        if ($adaylar !== []) {
            return $adaylar;
        }

        // ── KAPI NUMARASI GERİ ÇEKİLMESİ (2026-07-28, ölçüldü) ────────────────────────────
        // Yandex Geocoder Türkiye'de bina numarasını KATI eşleştirir: numara veritabanında
        // yoksa sokağa DÜŞMEZ, sıfır sonuç döner. Gerçek ölçüm:
        //
        //   "Şirinyalı Mah. 1497. Sk. No: 9 Muratpaşa/Antalya"  → found=0
        //   "Şirinyalı Mah. 1497. Sok. Antalya"                 → found=1  (sokak VAR)
        //
        // Yani sokak sistemde duruyor, yalnız 9 numaralı bina kaydı yok. Kullanıcıya
        // "bu adres bulunamadı" demek YANLIŞ olurdu: adres doğru, eksik olan Yandex'in bina
        // verisi. Numarayı düşürüp bir kez daha soruyoruz ve dönen adayın kesinliğini
        // ZORLA `sokak`a çekiyoruz — kapı numarası artık sorgunun parçası değil, bunu
        // "bina" diye sunmak kuryenin güvendiği bir yalan olurdu.
        $sade = self::kapiNumarasiniAt($sorgu);
        if ($sade !== null) {
            return $this->sokagaIndir($this->sor($sade, $enFazla));
        }

        return [];
    }

    /**
     * Tek bir Yandex sorgusu.
     *
     * @return list<GeoAday>
     */
    private function sor(string $sorgu, int $enFazla): array
    {
        try {
            $yanit = Http::timeout($this->timeout)
                ->acceptJson()
                ->get($this->baseUrl, [
                    'apikey' => $this->apiKey,
                    'geocode' => $sorgu,
                    'format' => 'json',
                    'results' => $enFazla,
                    'lang' => $this->lang,
                    // bbox arama merkezini Türkiye'ye çeker; rspn=0 ile SINIR DEĞİLDİR (sadece
                    // öncelik) — sınır dışına düşen sonuç zaten GeoAday::turkiyedeMi ile elenir.
                    'bbox' => $this->bbox,
                    'rspn' => 0,
                ]);
        } catch (ConnectionException) {
            throw GeocodingException::ulasilamadi();
        }

        if ($yanit->status() === 403 || $yanit->status() === 401) {
            // Anahtar geçersiz / kota bitti. Ham gerekçe İSTEMCİYE GİTMEZ, log'a yazılır.
            Log::warning('Yandex geocoder isteği reddetti', ['status' => $yanit->status()]);

            throw GeocodingException::reddedildi();
        }

        if (! $yanit->successful()) {
            Log::warning('Yandex geocoder beklenmedik yanıt', ['status' => $yanit->status()]);

            throw GeocodingException::ulasilamadi();
        }

        return $this->ayristir($yanit->json());
    }

    /**
     * Sorgudan KAPI/DAİRE bilgisini atar; atılacak bir şey yoksa `null` (ikinci sorgu boşuna
     * kota yakmasın — aynı metni iki kez sormanın anlamı yok).
     *
     * DİKKAT — sokak adındaki sayı KORUNUR. Türkiye'de sokaklar numaralıdır ("1497. Sok.");
     * "bütün sayıları at" demek sokağın kendisini silmek olurdu. Bu yüzden yalnız AÇIKÇA
     * numara olduğu yazan biçimler atılır: "No: 9", "no.9", "9/A" (blok/daire), "D:3", "Kat 2".
     */
    public static function kapiNumarasiniAt(string $sorgu): ?string
    {
        $desenler = [
            // "No: 9", "no12", "NO 12/3", "numara 9-A".
            // Numaradan sonraki harf EK ancak `/` veya `-` ile bağlıysa yutulur; düz boşluk
            // ardından gelen kelime bir SONRAKİ adres parçasıdır ("No: 9 Muratpaşa" →
            // "Muratpaşa" korunmalı, aksi hâlde ilçe silinir ve sorgu daha da bozulur).
            '/\bn(?:umara|o)\.?\s*[:.\-]?\s*\d+(?:\s*[\/\-]\s*[a-zA-Z0-9]+)?/iu',
            // "Daire 3", "Kat 2", "Blok B" — UZUN alternatif ÖNCE gelmeli: `d|daire` sırasıyla
            // regex "daire"nin yalnız "d"sini yer ve geriye "aire 5" kalırdı.
            '/\b(?:daire|blok|kat)\.?\s*[:.\-]?\s*[a-zA-Z0-9]+/iu',
            // "D:3" — tek harfli kısaltma YALNIZ ayraçlı biçimde. Ayraçsız kabul etseydik
            // "Cad." / "Cd." gibi kelimelerin içine dokunma riski doğardı.
            // "D:3" ve "d3" — tek harfli daire kısaltması. Ayraç zorunlu DEĞİL ama harften
            // hemen sonra rakam gelmeli; "Cad. 5" gibi yazımlarda `d`den önce sözcük sınırı
            // olmadığı için (a-d bitişik) bu desen oraya DOKUNMAZ.
            '/\bd\.?\s*[:.\-]?\s*\d+[a-zA-Z]?\b/iu',
        ];

        $sade = self::toparla(preg_replace($desenler, ' ', $sorgu) ?? $sorgu);

        // Karşılaştırma NORMALİZE edilmiş hâller arasında yapılır. Ham metinle kıyaslasaydık
        // toparlamanın kendisi (sarkan nokta/virgül kırpma) "değişti" sayılır ve numarası
        // OLMAYAN adreslerde de ikinci bir sorgu koşardı — boşuna kota.
        return ($sade === '' || $sade === self::toparla($sorgu)) ? null : $sade;
    }

    /**
     * Sarkan ayraçları ve fazla boşluğu toplar: "Cad. , Muratpaşa" → "Cad, Muratpaşa".
     * Virgülle bölüp boş parçaları atmak, regex'le noktalama kovalamaktan sağlamdır.
     */
    private static function toparla(string $metin): string
    {
        $parcalar = [];
        foreach (explode(',', $metin) as $p) {
            $p = trim(preg_replace('/\s+/u', ' ', $p) ?? $p);
            $p = trim($p, ' .-');
            if ($p !== '') {
                $parcalar[] = $p;
            }
        }

        return implode(', ', $parcalar);
    }

    /**
     * Kapı numarası düşürülerek bulunan adayların kesinliğini en fazla `sokak` yapar.
     * Yandex "exact" dese bile artık kapıyı DEĞİL sokağı bulduk; kullanıcı aday satırında
     * "sokak yaklaşık" uyarısını görmeli.
     *
     * @param  list<GeoAday>  $adaylar
     * @return list<GeoAday>
     */
    private function sokagaIndir(array $adaylar): array
    {
        return array_map(
            fn (GeoAday $a) => $a->kesinlik === GeoAday::KESINLIK_BINA
                ? new GeoAday($a->metin, $a->lat, $a->lng, GeoAday::KESINLIK_SOKAK)
                : $a,
            $adaylar
        );
    }

    /**
     * Yandex GeoObjectCollection → GeoAday listesi. Beklenmedik/eksik alan sessizce ATLANIR:
     * tek bozuk kayıt yüzünden bütün listeyi düşürmek kullanıcıyı boş yere adressiz bırakırdı.
     *
     * @param  mixed  $govde
     * @return list<GeoAday>
     */
    private function ayristir($govde): array
    {
        if (! is_array($govde)) {
            return [];
        }

        /** @var mixed $uyeler */
        $uyeler = data_get($govde, 'response.GeoObjectCollection.featureMember');
        if (! is_array($uyeler)) {
            return [];
        }

        $adaylar = [];
        /** @var mixed $uye */
        foreach ($uyeler as $uye) {
            $nesne = data_get($uye, 'GeoObject');
            if (! is_array($nesne)) {
                continue;
            }

            $pos = data_get($nesne, 'Point.pos');
            if (! is_string($pos)) {
                continue;
            }

            // "30.713 36.896" — BOYLAM önce.
            $parcalar = preg_split('/\s+/', trim($pos)) ?: [];
            if (count($parcalar) < 2 || ! is_numeric($parcalar[0]) || ! is_numeric($parcalar[1])) {
                continue;
            }

            $meta = data_get($nesne, 'metaDataProperty.GeocoderMetaData');
            $metin = data_get($meta, 'text');
            if (! is_string($metin) || $metin === '') {
                // Metinsiz aday kullanıcıya gösterilemez ("hangisini seçiyorum?").
                continue;
            }

            $aday = new GeoAday(
                metin: $this->kisalt($metin),
                lat: (float) $parcalar[1],
                lng: (float) $parcalar[0],
                kesinlik: $this->kesinlik(
                    is_string($p = data_get($meta, 'precision')) ? $p : '',
                    is_string($k = data_get($meta, 'kind')) ? $k : '',
                ),
            );

            if ($aday->turkiyedeMi()) {
                $adaylar[] = $aday;
            }
        }

        return $adaylar;
    }

    /**
     * Yandex her metne "Türkiye, " ön eki koyar; kurye listesinde bu 8 karakter her satırda
     * tekrar eder ve asıl ayırt edici kısmı (mahalle/sokak) ekrandan taşırır.
     */
    private function kisalt(string $metin): string
    {
        foreach (['Türkiye, ', 'Turkey, '] as $onEk) {
            if (str_starts_with($metin, $onEk)) {
                return substr($metin, strlen($onEk));
            }
        }

        return $metin;
    }

    /** Yandex `precision`/`kind` → bizim üç kademe. */
    private function kesinlik(string $precision, string $kind): string
    {
        if ($precision === 'exact' || $precision === 'number' || $kind === 'house') {
            return GeoAday::KESINLIK_BINA;
        }

        if ($precision === 'near' || $precision === 'range' || $precision === 'street'
            || $kind === 'street') {
            return GeoAday::KESINLIK_SOKAK;
        }

        return GeoAday::KESINLIK_SEMT;
    }
}
