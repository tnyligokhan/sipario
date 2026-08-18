<?php

namespace App\Support\Sync;

use InvalidArgumentException;

/**
 * ÜRÜN SEÇENEKLERİ sınır doğrulaması — biçim + tekillik + sayı (kullanıcı isteği 2026-08-18;
 * şema gerekçesi migration 004014'te, alan modeli mobilde `data/urun_secenekleri.dart`).
 *
 * `FavoriUrunler` (2026-08-11) ile AYNI çizgide ve aynı sebeplerle AYRI BİR DOSYA: `ChangeApplier`
 * zaten 500 satır sınırının üstünde ve kurallar durum tutmayan saf fonksiyonlara sığıyor.
 *
 * ══ NEDEN KATI ═════════════════════════════════════════════════════════════════════════════
 * Alan `json` kolonda bütün olarak durur ve İSTEMCİ onu sorgusuz okur. Bugün kabul ettiğimiz her
 * sapkın biçim, yarın telefonda ayrıştırılamayan bir satır demektir; mobil çözümleyici bozuk
 * girdide çökmez ama SESSİZCE BOŞA düşer — yani bayi malzeme listesini kaydettiğini sanır ve
 * liste hiç görünmez. Red ise savepoint ile yalnız o olayı düşürür, parti akmaya devam eder ve
 * istemci karantinada GÖRÜNÜR bir kayıt bırakır.
 *
 * ══ FİYAT DOĞRULAMASI ══════════════════════════════════════════════════════════════════════
 * `ekKurus` NEGATİF OLAMAZ. Negatif bir ek tutar satırın birim fiyatını düşürür ve bu, sunucu
 * tarafında hiçbir yerde sınırlanmayan bir indirim kanalı açardı — iskontonun kendi kaydı,
 * kendi yetkisi ve gün sonunda kendi satırı var (`ledger_entries.discount`); ikinci ve
 * denetlenmeyen bir indirim yolu para güvenliğini bozar.
 */
final class UrunSecenekleri
{
    /** Bir üründe durabilecek azami seçenek (kırpma değil, RED sınırı). */
    public const AZAMI_SECENEK = 24;

    /** Bir müşteride hatırlanabilecek azami ürün tercihi. */
    public const AZAMI_TERCIH = 60;

    /** Malzeme adının azami uzunluğu — mutfak fişine sığmayan bir ad zaten kullanılamaz. */
    private const AZAMI_AD = 40;

    /** Tek bir ekstranın azami ek ücreti (kuruş) — 10.000,00 ₺. Kasıtsız sıfır fazlasına karşı. */
    private const AZAMI_EK_KURUS = 1000000;

    /**
     * `products.options` — seçenek DİZİSİ. Geçersizse InvalidArgumentException; boşsa null.
     *
     * SIRA KORUNUR: bayi malzemeleri kendi düzenine göre dizer ve o düzen listenin taşıdığı
     * bilgidir (favori listesindeki kuralın aynısı).
     *
     * @return list<array{ad: string, varsayilan: bool, ekKurus: int}>|null
     */
    public static function liste(mixed $ham): ?array
    {
        if ($ham === null) {
            return null;
        }
        if (! is_array($ham) || ! array_is_list($ham)) {
            throw new InvalidArgumentException('options düz bir dizi olmalı');
        }

        $temiz = [];
        $gorulen = [];
        foreach ($ham as $eleman) {
            $secenek = self::secenek($eleman);
            $anahtar = mb_strtolower($secenek['ad']);
            // AYNI AD İKİ KEZ DURAMAZ: seçim `ad` üzerinden eşleşiyor (satır "Soğan çıkarıldı"
            // der, indeks numarası değil) ve tekrar eden ad hangi satırın kastedildiğini
            // belirsiz kılardı. İlk görülen kazanır — bayinin sırası korunur.
            if (isset($gorulen[$anahtar])) {
                continue;
            }
            $gorulen[$anahtar] = true;
            $temiz[] = $secenek;
        }

        if (count($temiz) > self::AZAMI_SECENEK) {
            throw new InvalidArgumentException(
                'options en çok '.self::AZAMI_SECENEK.' seçenek taşıyabilir'
            );
        }

        return $temiz === [] ? null : $temiz;
    }

    /**
     * `order_lines.options` — TEK bir seçim (`{cikarilan: [...], eklenen: [...]}`).
     *
     * @return array{cikarilan?: list<string>, eklenen?: list<array{ad: string, varsayilan: bool, ekKurus: int}>}|null
     */
    public static function secim(mixed $ham): ?array
    {
        if ($ham === null) {
            return null;
        }
        if (! is_array($ham) || array_is_list($ham)) {
            throw new InvalidArgumentException('options bir nesne olmalı');
        }

        $sonuc = [];

        $cikarilan = $ham['cikarilan'] ?? null;
        if ($cikarilan !== null) {
            if (! is_array($cikarilan) || ! array_is_list($cikarilan)) {
                throw new InvalidArgumentException('options.cikarilan düz bir dizi olmalı');
            }
            $adlar = [];
            foreach ($cikarilan as $ad) {
                $adlar[] = self::ad($ad, 'options.cikarilan');
            }
            $adlar = array_values(array_unique($adlar));
            if (count($adlar) > self::AZAMI_SECENEK) {
                throw new InvalidArgumentException('options.cikarilan çok uzun');
            }
            if ($adlar !== []) {
                $sonuc['cikarilan'] = $adlar;
            }
        }

        $eklenen = $ham['eklenen'] ?? null;
        if ($eklenen !== null) {
            if (! is_array($eklenen) || ! array_is_list($eklenen)) {
                throw new InvalidArgumentException('options.eklenen düz bir dizi olmalı');
            }
            $liste = [];
            foreach ($eklenen as $eleman) {
                $liste[] = self::secenek($eleman);
            }
            if (count($liste) > self::AZAMI_SECENEK) {
                throw new InvalidArgumentException('options.eklenen çok uzun');
            }
            if ($liste !== []) {
                $sonuc['eklenen'] = $liste;
            }
        }

        // BOŞ SEÇİM = NULL: "hiçbir şey değiştirilmedi" tek bir hâldir ve `{}` ile `null` iki
        // ayrı değer olsaydı istemcinin "seçim var mı" kapısı iki dala ayrılırdı.
        return $sonuc === [] ? null : $sonuc;
    }

    /**
     * `customers.product_options` — ürün kimliği → seçim haritası.
     *
     * ÜRÜNÜN VAR OLUP OLMADIĞI SORULMAZ (bilinçli, `FavoriUrunler` ile aynı gerekçe): senkron
     * SIRASI garanti değildir ve tercih, ürünün kendisinden önce inebilir. İstemci çözemediği
     * kimliği atlar.
     *
     * @return array<string, array<string, mixed>>|null
     */
    public static function tercihler(mixed $ham): ?array
    {
        if ($ham === null) {
            return null;
        }
        if (! is_array($ham) || array_is_list($ham)) {
            throw new InvalidArgumentException('product_options bir nesne olmalı');
        }

        $temiz = [];
        foreach ($ham as $urunId => $secim) {
            if (! is_string($urunId) || trim($urunId) === '') {
                throw new InvalidArgumentException('product_options anahtarı ürün kimliği olmalı');
            }
            if (mb_strlen($urunId) > 64) {
                throw new InvalidArgumentException('product_options anahtarı çok uzun');
            }
            $cozulen = self::secim($secim);
            if ($cozulen === null) {
                continue; // boş tercih saklanmaz
            }
            $temiz[trim($urunId)] = $cozulen;
        }

        if (count($temiz) > self::AZAMI_TERCIH) {
            throw new InvalidArgumentException(
                'product_options en çok '.self::AZAMI_TERCIH.' ürün taşıyabilir'
            );
        }

        return $temiz === [] ? null : $temiz;
    }

    /**
     * @return array{ad: string, varsayilan: bool, ekKurus: int}
     */
    private static function secenek(mixed $ham): array
    {
        if (! is_array($ham) || array_is_list($ham)) {
            throw new InvalidArgumentException('seçenek bir nesne olmalı');
        }

        $ek = $ham['ekKurus'] ?? 0;
        if (! is_int($ek)) {
            throw new InvalidArgumentException('ekKurus tam sayı olmalı');
        }
        if ($ek < 0) {
            // Gerekçe sınıf başlığında: negatif ek tutar, denetlenmeyen ikinci bir indirim
            // kanalıdır. İskontonun kendi kaydı ve kendi yetkisi var.
            throw new InvalidArgumentException('ekKurus negatif olamaz');
        }
        if ($ek > self::AZAMI_EK_KURUS) {
            throw new InvalidArgumentException('ekKurus çok büyük');
        }

        $varsayilan = $ham['varsayilan'] ?? true;
        if (! is_bool($varsayilan)) {
            throw new InvalidArgumentException('varsayilan mantıksal olmalı');
        }

        return [
            'ad' => self::ad($ham['ad'] ?? null, 'seçenek adı'),
            'varsayilan' => $varsayilan,
            'ekKurus' => $ek,
        ];
    }

    private static function ad(mixed $ham, string $alan): string
    {
        if (! is_string($ham)) {
            throw new InvalidArgumentException($alan.' metin olmalı');
        }
        $ad = trim($ham);
        if ($ad === '') {
            throw new InvalidArgumentException($alan.' boş olamaz');
        }
        if (mb_strlen($ad) > self::AZAMI_AD) {
            throw new InvalidArgumentException($alan.' '.self::AZAMI_AD.' karakterden uzun olamaz');
        }

        return $ad;
    }
}
