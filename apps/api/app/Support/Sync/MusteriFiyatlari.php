<?php

namespace App\Support\Sync;

use InvalidArgumentException;

/**
 * `customers.product_prices` sınır doğrulaması — ürün kimliği → birim fiyat (kuruş) haritası
 * (kullanıcı isteği 2026-11-05: müşteriye özel ürün fiyatı).
 *
 * `FavoriUrunler` ve `UrunSecenekleri::tercihler` ile aynı çizgi: ÜRÜNÜN VAR OLUP OLMADIĞI SORULMAZ
 * (senkron sırası garanti değil, istemci çözemediği kimliği atlar) ve aşan liste KIRPILMAZ, reddedilir.
 * Red savepoint ile yalnız o olayı düşürür, parti akmaya devam eder.
 *
 * SIFIR FİYAT GEÇERLİDİR: bayi bir müşteriye ürünü bedelsiz verebilir. Negatif geçersizdir; fiyatı
 * kaldırmak anahtarı silmektir, sıfır yazmak değil.
 */
final class MusteriFiyatlari
{
    public const AZAMI_URUN = 300;

    /** Yazım hatasını yakalayan üst sınır: 100 milyon ₺. */
    public const AZAMI_KURUS = 10_000_000_000;

    private const AZAMI_ID_HANE = 64;

    /**
     * Boş harita null'a iner: "özel fiyatı yok" tek bir hâldir.
     *
     * @return array<string, int>|null
     */
    public static function dogrula(mixed $ham): ?array
    {
        if ($ham === null || $ham === []) {
            return null;
        }
        if (! is_array($ham) || array_is_list($ham)) {
            throw new InvalidArgumentException('product_prices bir nesne olmalı');
        }
        if (count($ham) > self::AZAMI_URUN) {
            throw new InvalidArgumentException('product_prices en çok '.self::AZAMI_URUN.' ürün taşıyabilir');
        }

        $temiz = [];
        foreach ($ham as $urunId => $kurus) {
            $id = trim((string) $urunId);
            if ($id === '' || strlen($id) > self::AZAMI_ID_HANE) {
                throw new InvalidArgumentException('product_prices anahtarı ürün kimliği olmalı');
            }
            if (! is_int($kurus) || $kurus < 0 || $kurus > self::AZAMI_KURUS) {
                throw new InvalidArgumentException('product_prices değeri geçerli bir kuruş olmalı');
            }
            $temiz[$id] = $kurus;
        }

        return $temiz;
    }
}
