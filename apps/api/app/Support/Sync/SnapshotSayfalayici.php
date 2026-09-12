<?php

namespace App\Support\Sync;

use App\Models\CallLog;
use App\Models\CashHandover;
use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Models\DayClosing;
use App\Models\ExemptNumber;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\OrderEvent;
use App\Models\OrderLine;
use App\Models\Product;
use App\Models\TenantSetting;
use Illuminate\Database\Eloquent\Model;

/**
 * İLK SENKRONUN SAYFALANMASI — 2026-09-12 saha arızasının kapağı.
 *
 * YAŞANAN: bir bayiye 9.047 müşteri aktarıldı (13.263 telefon, 8.867 adres). Yeni giriş yapan
 * telefon `since=0` ile SNAPSHOT istiyor ve sunucu bunu TEK PARÇA üretiyordu — ölçüldü:
 * **15,3 MB, 8,5 saniye, 92 MB tepe bellek**. İstemcinin HTTP zaman aşımı 25 saniyedir; üretim
 * süresi + 15 MB indirme mobil veride o pencereye sığmaz. Sonuç: bayinin telefonunda ürünler ve
 * müşterilerin çoğu HİÇ görünmedi, panelde hepsi duruyordu.
 *
 * Bu yalnız o bayinin sorunu değildi: **büyük müşteri listesiyle gelen HER yeni bayi aynı duvara
 * çarpardı.** Ürünün taşıma vaadi (BRIEF: "veri rehin alınmaz") giriş yönünde çalışmıyordu.
 *
 * SAYFALAMA İSTEĞE BAĞLIDIR VE BU BİLİNÇLİDİR: istemci `snapshot_cursor` göndererek yeteneğini
 * BİLDİRİR. Parametresiz istek eski (tek parça) davranışı görür. Koşulsuz açmak sahadaki
 * 1.2.0/1.3.0 telefonlarını KIRARDI — onlar snapshot modunda `has_more`u izlemiyor, ilk sayfada
 * imleci sona damgalayıp geri kalanı bir daha hiç istemezlerdi (tam da düzeltmeye çalıştığımız
 * arızanın daha kötü hâli).
 *
 * SIRA SABİTTİR ve `id`ye göre dizilir: sayfalama ancak deterministik bir sıra üzerinde
 * sürdürülebilir. Sıra değişirse imleç anlamını yitirir ve satır atlanır/tekrarlanır.
 */
final class SnapshotSayfalayici
{
    /**
     * Varlık sırası — `SyncService::snapshot()` ile AYNI kümedir ve öyle kalmalıdır: iki liste
     * ayrışırsa sayfalı ve sayfasız ilk senkron FARKLI veri indirir, üstelik sessizce.
     *
     * Üçüncü alan: tombstone süzülsün mü (append-only tablolarda satır silinmez, süzgeç yoktur).
     *
     * @var list<array{0: string, 1: class-string<Model>, 2: bool}>
     */
    private const SIRA = [
        ['customer', Customer::class, true],
        ['customer_phone', CustomerPhone::class, true],
        ['customer_address', CustomerAddress::class, true],
        ['product', Product::class, true],
        ['order', Order::class, true],
        ['order_line', OrderLine::class, true],
        ['order_event', OrderEvent::class, false],
        ['ledger_entry', LedgerEntry::class, false],
        ['cash_handover', CashHandover::class, false],
        ['tenant_settings', TenantSetting::class, false],
        ['exempt_number', ExemptNumber::class, true],
        ['call_log', CallLog::class, true],
        ['day_closing', DayClosing::class, false],
    ];

    /**
     * Bir snapshot sayfası.
     *
     * @param  string  $imlec  "<tip>:<son-id>" — boş metin baştan başlar.
     * @return array<string, mixed>
     */
    public static function sayfa(int $currentSeq, int $limit, string $imlec): array
    {
        [$baslangicTipi, $sonId] = self::imleciCoz($imlec);

        $varliklar = [];
        $kalan = $limit;
        $yeniImlec = null;
        $basladi = $baslangicTipi === null;

        foreach (self::SIRA as [$tip, $sinif, $tombstoneSuz]) {
            // İmlecin bıraktığı tipe kadar atla. Bulunduğunda O TİPTEN devam edilir (aynı tipin
            // kalan satırları olabilir), sonraki tipler baştan okunur.
            if (! $basladi) {
                if ($tip !== $baslangicTipi) {
                    continue;
                }
                $basladi = true;
            } else {
                $sonId = null;
            }

            if ($kalan <= 0) {
                break;
            }

            $satirlar = self::oku($sinif, $tombstoneSuz, $sonId, $kalan);
            if ($satirlar !== []) {
                $varliklar[$tip] = array_map(fn (Model $m) => $m->toArray(), $satirlar);
                $kalan -= count($satirlar);
                $yeniImlec = $tip.':'.self::anahtar(end($satirlar));
            }

            if ($kalan <= 0) {
                break;
            }
        }

        /**
         * SAYFA DOLDUYSA "DEVAMI VAR" DENİR — kalan gerçekten var mı diye ayrıca sorulmaz.
         * Bedeli, tam sınırda biten bir snapshot'ta BİR fazladan boş tur; karşılığı, her sayfada
         * ikinci bir sayım sorgusu koşmamak. Boş tur zararsızdır: `has_more=false` ile döner ve
         * istemci orada biter.
         */
        $devamVar = $kalan <= 0;

        return [
            'mode' => 'snapshot',
            'cursor' => $currentSeq,
            'has_more' => $devamVar,
            'snapshot_cursor' => $devamVar ? $yeniImlec : null,
            'current_seq' => $currentSeq,
            'entities' => $varliklar,
        ];
    }

    // ------------------------------------------------------------------------------------

    /**
     * @param  class-string<Model>  $sinif
     * @return list<Model>
     */
    private static function oku(string $sinif, bool $tombstoneSuz, ?string $sonId, int $limit): array
    {
        $ornek = new $sinif;
        $anahtar = $ornek->getKeyName();

        $sorgu = $sinif::query()->orderBy($anahtar)->limit($limit);
        if ($tombstoneSuz) {
            $sorgu->whereNull('deleted_at');
        }
        if ($sonId !== null && $sonId !== '') {
            $sorgu->where($anahtar, '>', $sonId);
        }

        return array_values($sorgu->get()->all());
    }

    private static function anahtar(Model $m): string
    {
        return (string) $m->getKey();
    }

    /**
     * "<tip>:<id>" → [tip, id]. Tanınmayan/boş imleç BAŞTAN başlatır.
     *
     * TANINMAYAN TİP SESSİZCE BAŞA DÖNER, hata vermez: imleci üreten de tüketen de biziz, ama
     * varlık listesi bir gün değişirse (tip kaldırılırsa) sahadaki yarım kalmış bir senkron
     * 500 almamalı — baştan başlamak yavaştır, kırılmaktan iyidir.
     *
     * @return array{0: ?string, 1: ?string}
     */
    private static function imleciCoz(string $imlec): array
    {
        if ($imlec === '' || ! str_contains($imlec, ':')) {
            return [null, null];
        }

        [$tip, $id] = explode(':', $imlec, 2);
        $tipler = array_column(self::SIRA, 0);

        return in_array($tip, $tipler, true) ? [$tip, $id] : [null, null];
    }
}
