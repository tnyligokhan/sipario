<?php

namespace App\Support\Sync;

use InvalidArgumentException;

/**
 * `customers.favorite_product_ids` sınır doğrulaması — biçim + tekillik + sayı
 * (kullanıcı isteği 2026-08-11; şema gerekçesi migration 004010'da).
 *
 * NEDEN AYRI DOSYA: `ChangeApplier` zaten 500 satır sınırının üstünde ve bu depoda o sınır bir
 * üslup tercihi değil, sınıfın okunabilir kalmasının kapısı (OrderChangeApplier/ProfileChangeApplier
 * aynı gerekçeyle ayrıldı). Kurallar tek bir SAF fonksiyona sığıyor; durum tutmuyor.
 *
 * Kabul edilen TEK biçim: string id'lerden oluşan DÜZ dizi. Nesne (`{"id":…}`), iç içe dizi, sayı,
 * boolean ve JSON METNİ (`'["a"]'`) REDDEDİLİR. Gevşek davranmanın bedeli burada ağırdır: alan
 * `text` kolonda bütün olarak durur ve İSTEMCİ onu sorgusuz okur — bugün kabul ettiğimiz her
 * sapkın biçim, yarın telefonda ayrıştırılamayan bir satır demektir (mobil ayrıştırıcı sözleşmesi:
 * alan ne ise o). Red savepoint ile yalnız o olayı düşürür, parti akmaya devam eder.
 *
 * ÜRÜNÜN VAR OLUP OLMADIĞI SORULMAZ (bilinçli, lead kararı): ürün silinmiş olabilir ve senkron
 * SIRASI garanti değildir — favori listesi ürünün kendisinden önce inebilir. Var olmayan bir id
 * yüzünden yarım kalmış bir sipariş partisini düşürmek orantısız olurdu; istemci çözemediği id'yi
 * ATLAR. Bu, `customer_id`/`product_id` referans doğrulamasından bilinçli bir SAPMADIR: oradaki
 * kapı cross-tenant POISON'a karşıdır (FK ihlali transaction'ı zehirler), burada FK yoktur.
 */
final class FavoriUrunler
{
    /** Bayinin listesinde durabilecek azami ürün (kırpma değil, RED sınırı). */
    public const AZAMI = 20;

    /**
     * Tek bir id'nin azami uzunluğu. Bir kimlik BİÇİMİ dayatmaz (uuid7 = 36 hane, bol pay var);
     * yalnız tek bir bozuk istemcinin megabaytlık dizeleri sınırsız `text` kolona ve oradan her
     * senkron turuna sokmasını engeller.
     */
    private const AZAMI_ID_HANE = 64;

    /**
     * Ham payload değerini kolona yazılacak listeye çevirir; geçersizse InvalidArgumentException.
     *
     * SIRA KORUNUR, alfabetik sıralama YOK: sıra bayinin tercihidir (en sık aldığı ürün başta) ve
     * onu yeniden dizmek listenin taşıdığı BİLGİYİ siler.
     *
     * ÖNCE TEKLEME, SONRA SAYI SINIRI — bu sıra bilinçlidir: tekrar bir İSTEMCİ HATASIDIR, bayinin
     * niyeti değil; 25 gönderip 15'i tekil olan bir listeyi reddetmek bayiye kendi yapmadığı bir
     * hatanın bedelini ödetirdi. Sınırın koruduğu şey EFEKTİF listedir. Teklemeden sonra hâlâ
     * aşıyorsa RED — KIRPMA YOK: sessizce kırpmak bayinin listesinden ürün siler ve bunu ancak
     * sipariş ekranında ürünü bulamayınca fark eder (`iban`ın 34 hane kapısıyla aynı çizgi).
     *
     * BOŞ DİZİ = NULL: "favorisi yok" tek bir hâldir; `[]` ile `null` iki ayrı değer olsaydı
     * istemcinin "liste boş mu" kapısı iki dala ayrılır, ikisinden biri er geç unutulurdu.
     *
     * @return list<string>|null
     */
    public static function dogrula(mixed $ham): ?array
    {
        if ($ham === null) {
            return null;
        }
        if (! is_array($ham) || ! array_is_list($ham)) {
            throw new InvalidArgumentException('favorite_product_ids düz bir dizi olmalı');
        }

        $temiz = [];
        foreach ($ham as $eleman) {
            if (! is_string($eleman)) {
                throw new InvalidArgumentException('favorite_product_ids yalnız metin id taşıyabilir');
            }
            $id = trim($eleman);
            if ($id === '') {
                throw new InvalidArgumentException('favorite_product_ids boş id taşıyamaz');
            }
            if (mb_strlen($id) > self::AZAMI_ID_HANE) {
                throw new InvalidArgumentException(
                    'favorite_product_ids id\'si '.self::AZAMI_ID_HANE.' karakterden uzun olamaz'
                );
            }
            $temiz[] = $id;
        }

        $temiz = array_values(array_unique($temiz));

        if (count($temiz) > self::AZAMI) {
            throw new InvalidArgumentException(
                'favorite_product_ids en çok '.self::AZAMI.' ürün taşıyabilir'
            );
        }

        return $temiz === [] ? null : $temiz;
    }
}
