<?php

namespace App\Support\Sync;

use InvalidArgumentException;

/**
 * `tenant_settings.expense_categories` sınır doğrulaması — bayinin gider kategorileri
 * (kullanıcı isteği 2026-11-05). Kategori bir ETİKETTİR: gider kaydına metin olarak yazılır, bu
 * listeyle ilişkisel bağı yoktur. Listeden silinen kategori eski giderleri etkilemez.
 *
 * Tekrarlar tam eşleşmeyle teklenir: büyük/küçük harf ayrımı istemcinin işidir ve sunucunun metni
 * değiştirmesi bayinin yazdığını bozardı.
 */
final class GiderKategorileri
{
    public const AZAMI_KATEGORI = 40;

    public const AZAMI_HANE = 40;

    /**
     * Boş liste null'a iner ve bu bilinçli bir ödündür: istemcide null "varsayılan liste" demektir,
     * yani bütün kategorileri silmek varsayılanı geri getirirdi. İstemci son kategorinin silinmesini
     * bu yüzden engeller.
     *
     * @return list<string>|null
     */
    public static function dogrula(mixed $ham): ?array
    {
        if ($ham === null || $ham === []) {
            return null;
        }
        if (! is_array($ham) || ! array_is_list($ham)) {
            throw new InvalidArgumentException('expense_categories düz bir dizi olmalı');
        }

        $temiz = [];
        foreach ($ham as $eleman) {
            if (! is_string($eleman)) {
                throw new InvalidArgumentException('expense_categories metinlerden oluşmalı');
            }
            $ad = trim($eleman);
            if ($ad === '' || mb_strlen($ad) > self::AZAMI_HANE) {
                throw new InvalidArgumentException('expense_categories elemanı en çok '.self::AZAMI_HANE.' karakter olabilir');
            }
            if (! in_array($ad, $temiz, true)) {
                $temiz[] = $ad;
            }
        }
        if (count($temiz) > self::AZAMI_KATEGORI) {
            throw new InvalidArgumentException('expense_categories en çok '.self::AZAMI_KATEGORI.' kategori taşıyabilir');
        }

        return $temiz;
    }
}
