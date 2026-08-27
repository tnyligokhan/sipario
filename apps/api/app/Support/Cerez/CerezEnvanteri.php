<?php

declare(strict_types=1);

namespace App\Support\Cerez;

/**
 * ÇEREZ ENVANTERİ — config/cerezler.php'yi okunabilir, çözülmüş bir nesneye çevirir.
 *
 * ── NEDEN SINIF, NEDEN DOĞRUDAN config() DEĞİL ───────────────────────────────────────────────
 * Üç ayrı tüketici var ve üçü de AYNI cevabı almak zorunda: çerez tercih penceresi (Blade),
 * Çerez Politikası belgesi (Blade) ve tarayıcı tarafı (public/js/cerez.js'e giden JSON).
 * Her biri config'i kendi okusaydı üç yerde birden yer tutucu çözme, koşul değerlendirme ve
 * rıza değeri ayrıştırma kodu olurdu — ve ilk sapan taraf sessizce yanlış bilgilendirme üretirdi.
 *
 * Proje kuralı gereği (CLAUDE.md, 2026-08-17) durum ve onun üzerinde işleyen davranış aynı
 * nesnede kapsüllenir: envanterin ham hâli içeride kalır, dışarıya yalnız çözülmüş liste ve
 * rıza soruları açılır.
 *
 * ── RIZA ÇEREZİNİN DEĞER BİÇİMİ ──────────────────────────────────────────────────────────────
 *   "<surum>|<izin verilen kategoriler, virgülle>"     örn:  "1|olcum"   ·   "1|"  (hepsi ret)
 *
 * Biçim BİLEREK okunabilir: ziyaretçi DevTools'ta çerezine bakınca ne kabul ettiğini görebilmeli.
 * JSON da olabilirdi ama `{`/`"` karakterleri çerez değerinde yüzde kaçışı gerektirir ve
 * tarayıcıda okunmaz bir dizeye döner. Kullanılan karakterlerin (harf, rakam, `|`, `,`) hepsi
 * çerez değerinde kaçışsız geçerlidir — bu yüzden JS tarafı da encodeURIComponent KULLANMAZ.
 *
 * ── ESKİ BİÇİM (`kabul` / `ret`) ONURLANDIRILIR ──────────────────────────────────────────────
 * 2026-08-19'daki ilk sürüm tek düğmeliydi ve çerezi `kabul`/`ret` diye yazıyordu. O ziyaretçiler
 * kararlarını GEÇERLİ bir listeye vermişti (liste o gün de bugünkünün aynısıydı); sürüm
 * uyuşmazlığı sayıp herkese pencereyi yeniden açmak, hiçbir hukuki kazanç sağlamadan rıza
 * yorgunluğu üretirdi. `kabul` → ölçüme izin var, `ret` → yok.
 */
final class CerezEnvanteri
{
    /** Eski tek düğmeli sürümün yazdığı değerler — bugünkü kategorilere karşılığı. */
    private const ESKI_BICIM = ['kabul' => ['olcum'], 'ret' => []];

    /** @var array<string,mixed> */
    private readonly array $ham;

    /*
     * Yapılandırma DIŞARIDAN GEÇİLMEZ, config'ten okunur. Bir "enjeksiyon deliği" bırakmak
     * cazipti ama kullananı olmayacaktı: testler zaten `config([...])` ile ortamı kuruyor ve
     * ikinci bir kurulum yolu, ürün kodunun okuduğu listeden BAŞKA bir listeyi test etme
     * ihtimalini açardı.
     */
    public function __construct()
    {
        $this->ham = (array) config('cerezler', []);
    }

    public function cerezAdi(): string
    {
        return (string) ($this->ham['cerez'] ?? 'sipario_cerez_izni');
    }

    public function gun(): int
    {
        return (int) ($this->ham['gun'] ?? 180);
    }

    public function surum(): int
    {
        return (int) ($this->ham['surum'] ?? 1);
    }

    /** @return list<string> */
    public function kullanilmayanlar(): array
    {
        return array_values((array) ($this->ham['yok'] ?? []));
    }

    /**
     * Bu kurulumda GERÇEKTEN var olan kategoriler, yer tutucuları çözülmüş hâlde.
     *
     * Koşulu sağlanmayan kategori listeden DÜŞER. Ölçüm kapalı bir kurulumda "Ölçüm çerezleri"
     * başlığı göstermek, kurulmayan bir çerez için rıza istemek olurdu — hem ziyaretçiyi boş
     * yere rahatsız eder hem de belgeyi yanlış hâle getirir.
     *
     * @return array<string,array<string,mixed>>
     */
    public function kategoriler(): array
    {
        $cikti = [];

        foreach ((array) ($this->ham['kategoriler'] ?? []) as $anahtar => $kategori) {
            if (! $this->kosulSaglandiMi($kategori['kosul'] ?? null)) {
                continue;
            }

            $cikti[(string) $anahtar] = [
                'anahtar' => (string) $anahtar,
                'ad' => (string) ($kategori['ad'] ?? $anahtar),
                'ozet' => (string) ($kategori['ozet'] ?? ''),
                'zorunlu' => (bool) ($kategori['zorunlu'] ?? false),
                'dayanak' => (string) ($kategori['dayanak'] ?? ''),
                'cerezler' => array_map(
                    fn (array $cerez): array => array_map(
                        fn ($deger) => is_string($deger) ? $this->coz($deger) : $deger,
                        $cerez
                    ),
                    array_values((array) ($kategori['cerezler'] ?? []))
                ),
            ];
        }

        return $cikti;
    }

    /**
     * Rızaya bağlı kategoriler (zorunlu olmayanlar).
     *
     * @return array<string,array<string,mixed>>
     */
    public function secmeliKategoriler(): array
    {
        return array_filter($this->kategoriler(), fn (array $k): bool => ! $k['zorunlu']);
    }

    /**
     * Ziyaretçiye rıza sorulmalı mı?
     *
     * Cevap "site çerez kullanıyor mu"ya değil, "RIZAYA BAĞLI çerez kullanıyor mu"ya bakar.
     * Yalnız zorunlu çerez varsa sorulacak bir şey yoktur; bant basmak, cevabı olmayan bir soru
     * sormaktır. (Zorunlu çerezlerin bilgilendirmesi Çerez Politikası'nda yapılır — orada
     * ölçüm kapalıyken de görünürler.)
     */
    public function rizaGerekiyorMu(): bool
    {
        return $this->secmeliKategoriler() !== [];
    }

    /**
     * Ziyaretçi bu listeye dair kararını vermiş mi?
     *
     * Sürüm uyuşmazlığı "karar verilmemiş" sayılır: rıza, verildiği listeye aittir (KVKK
     * m.3/1-a — belirli bir konuya ilişkin). Liste büyüdüyse eski onay yeni maddeyi kapsamaz.
     */
    public function kararVerilmisMi(?string $cerezDegeri): bool
    {
        return $this->cozumle($cerezDegeri) !== null;
    }

    /** Belirli bir kategoriye izin verilmiş mi? Zorunlu kategoriler her zaman açıktır. */
    public function izinliMi(string $anahtar, ?string $cerezDegeri): bool
    {
        $kategori = $this->kategoriler()[$anahtar] ?? null;
        if ($kategori === null) {
            return false;
        }
        if ($kategori['zorunlu']) {
            return true;
        }

        return in_array($anahtar, $this->cozumle($cerezDegeri) ?? [], true);
    }

    /**
     * public/js/cerez.js'e JSON kanalıyla geçen ayar. Betiğin ihtiyacı olan HER ŞEY burada:
     * çerezin adı, ömrü, sürümü ve hangi kategorilerin anahtarlanabilir olduğu. Betik config'i
     * ikinci bir yerden tahmin etmez.
     *
     * @return array<string,mixed>
     */
    public function tarayiciAyari(): array
    {
        return [
            'cerez' => $this->cerezAdi(),
            'gun' => $this->gun(),
            'surum' => $this->surum(),
            'kategoriler' => array_keys($this->secmeliKategoriler()),
        ];
    }

    /**
     * Çerez değerini izin verilen kategori listesine çevirir. Karar verilmemişse (çerez yok,
     * biçim bozuk ya da sürüm eski) `null` döner — bu, "boş liste" ile AYNI ŞEY DEĞİLDİR:
     * boş liste "hepsini reddettim" demektir ve tekrar sorulmaz.
     *
     * @return list<string>|null
     */
    private function cozumle(?string $deger): ?array
    {
        if ($deger === null || $deger === '') {
            return null;
        }

        if (array_key_exists($deger, self::ESKI_BICIM)) {
            return self::ESKI_BICIM[$deger];
        }

        if (! str_contains($deger, '|')) {
            return null;
        }

        [$surum, $izinler] = explode('|', $deger, 2);

        if ((int) $surum !== $this->surum()) {
            return null;
        }

        $secmeli = array_keys($this->secmeliKategoriler());

        return array_values(array_intersect(
            array_filter(array_map('trim', explode(',', $izinler)), fn (string $a): bool => $a !== ''),
            $secmeli
        ));
    }

    /** Kategori koşulu. Bugün tek koşul var; yenisi eklenirse burada tek satır olur. */
    private function kosulSaglandiMi(?string $kosul): bool
    {
        return match ($kosul) {
            null, '' => true,
            'analitik' => (bool) config('analitik.enabled') && (string) config('analitik.measurement_id') !== '',
            default => false,
        };
    }

    /** `%…%` yer tutucularını çalışma anındaki gerçek değerlerle değiştirir. */
    private function coz(string $metin): string
    {
        if (! str_contains($metin, '%')) {
            return $metin;
        }

        return strtr($metin, [
            '%oturum_cerezi%' => (string) config('session.cookie'),
            '%oturum_dk%' => (string) (int) config('session.lifetime'),
            '%riza_cerezi%' => $this->cerezAdi(),
            '%riza_ay%' => (string) (int) round($this->gun() / 30),
            '%ga4%' => (string) config('analitik.measurement_id'),
        ]);
    }
}
