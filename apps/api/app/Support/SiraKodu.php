<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;

/**
 * Kiracı içinde SIRA NUMARASI dağıtıcısı — müşteri kodu (102) ve sipariş kodu (#248).
 *
 * NEDEN SUNUCUDA: sıra numarası tek bir dağıtıcı ister. İstemci kendi üretseydi iki cihaz
 * çevrimdışıyken aynı numarayı alır, senkronda biri değiştirilmek zorunda kalırdı; bayinin
 * kâğıda yazdığı numaranın sonradan başka bir kayda ait olması para bitişiğinde kabul edilemez.
 *
 * NEDEN ADVISORY LOCK: iki cihaz aynı anda push ederse ikisi de aynı MAX'ı okur ve ikincisi
 * kısmi unique indekse çarpar — olay 'rejected' olur, yani KAYIT KAYBOLUR gibi görünür (kırmızı
 * çizgi #3: hiçbir kayıt kaybolmaz). `pg_advisory_xact_lock` dağıtımı kiracı başına sıraya
 * dizer; kilit transaction sonunda kendiliğinden düşer (açık unlock yok, sızdırmaz) ve
 * FARKLI kiracılar birbirini beklemez.
 *
 * NEDEN SEQUENCE DEĞİL: Postgres sequence'i kiracı başına açmak (tenant sayısı × 2 sequence)
 * şema yönetimini kiracı ömrüne bağlardı; ayrıca sequence boşluk bırakır (rollback'te sayı
 * yanar) ve bayi "101'den 103'e neden atladı" diye sorar.
 */
final class SiraKodu
{
    /** İlk kod 100'dür (kullanıcının verdiği örnek: 100, 101, 102). */
    public const BASLANGIC = 100;

    /**
     * Kiracıdaki bir sonraki boş kodu ayırır. Çağıran AÇIK BİR TRANSACTION içinde olmalıdır
     * (senkron uygulayıcıları öyle çalışır) — kilit transaction ömrüne bağlıdır.
     *
     * $tablo bir SQL TANIMLAYICISIDIR ve sorguya doğrudan girer (bağlanamaz). Beyaz liste bu
     * yüzden vardır ve tip ipucuyla değiştirilemez: çağıran yeri değişken bir ad geçirirse
     * (ör. istemciden gelen bir alan) tablo adı enjeksiyonu doğardı.
     */
    public static function sonraki(string $tablo, string $tenantId): int
    {
        if (! in_array($tablo, ['customers', 'orders'], true)) {
            throw new \InvalidArgumentException("Kod dagitilmayan tablo: {$tablo}");
        }

        DB::select('SELECT pg_advisory_xact_lock(hashtext(?))', ["sipario:{$tablo}:{$tenantId}"]);

        // tenant_id süzgeci RLS'in ÜSTÜNE açıkça yazılır: bu sorgu bir kimlik üretiyor ve
        // kapsamı politikadan okumak yerine sorgunun kendisinde görünür olmalı.
        $max = DB::table($tablo)->where('tenant_id', $tenantId)->max('code');

        return max((int) $max, self::BASLANGIC - 1) + 1;
    }
}
