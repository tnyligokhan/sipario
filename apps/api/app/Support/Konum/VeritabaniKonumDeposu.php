<?php

namespace App\Support\Konum;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Konum deposunun Postgres implementasyonu. RLS altında koşar (sipario_app rolü) — kiracı
 * filtresi SQL'de değil, politikada durur.
 *
 * Eloquent modeli yok, bilinçli: bu tablonun iş kuralı yok, ilişkisi yok, olayı yok — saniyede
 * bir ezilen tek satır. Sorgu kurucusu hem upsert'i tek SQL ifadesinde ifade eder hem de
 * canlı liste sorgusunda users ile join'i model hidrasyonu maliyeti olmadan yapar.
 */
final class VeritabaniKonumDeposu implements KonumDeposu
{
    private const TABLO = 'courier_locations';

    /**
     * Tek SQL ifadesi: INSERT ... ON CONFLICT (user_id) DO UPDATE.
     *
     * NEDEN SELECT-SONRA-INSERT (ya da updateOrCreate) DEĞİL: iki cihaz aynı anda kalp atışı
     * gönderirse ikisi de "satır yok" görür ve ikisi de INSERT dener — biri birincil anahtar
     * çakışmasıyla 500 verirdi. Üstelik RLS altında SELECT başka kiracının satırını GÖREMEZ,
     * yani "yok" cevabı yanıltıcıdır. ON CONFLICT bu yarışı DB'nin içinde çözer.
     *
     * `tenant_id` GÜNCELLENMEZ (çakışma dalında yok): kullanıcının bayisi değişmez ve bu
     * sütunu yazılabilir bırakmak, mevcut bir satırın kiracısını kaydırma yolu açardı.
     * Kompozit FK zaten imkânsız kılıyor — burada ikinci kilit.
     */
    public function kalpAtisiKaydet(User $kullanici, float $lat, float $lng, ?float $dogrulukM): void
    {
        DB::table(self::TABLO)->upsert(
            [[
                'user_id' => $kullanici->id,
                'tenant_id' => $kullanici->tenant_id,
                'lat' => $lat,
                'lng' => $lng,
                'accuracy_m' => $dogrulukM,
                // Damga SUNUCU saatidir: esnafın telefon saati yanlış olabilir, tazelik kararı
                // istemcinin saatine emanet edilemez (DECISIONS: sunucu saati tek doğru kaynak).
                'reported_at' => now(),
            ]],
            ['user_id'],
            ['lat', 'lng', 'accuracy_m', 'reported_at'],
        );
    }

    /**
     * Canlı liste. İki eşik de BURADA uygulanır (bkz. config/konum.php):
     *  - `liste_dakika`'dan eski satır sorgudan HİÇ dönmez — gizlilik sınırı, WHERE'dedir ki
     *    unutulabilir bir sonraki adıma (map/filter) bırakılmasın.
     *  - `taze_dakika` yalnız bir BAYRAK üretir; satır listede kalır, istemci soluk gösterir.
     *
     * users ile join: ad ve rol o tablonun gerçeğidir, konum satırında kopyalanmaz (kopyalansaydı
     * kullanıcı adını değiştirdiğinde harita eski adı göstermeye devam ederdi). İki tablo da
     * RLS'e tabidir — join kiracı sızıntısı için ikinci bir kapı açmaz.
     *
     * @return list<CanliKonum>
     */
    public function canliListe(): array
    {
        $simdi = CarbonImmutable::now();
        $listeEsigi = $simdi->subMinutes($this->dakika('liste_dakika', 60));
        $tazeEsigi = $simdi->subMinutes($this->dakika('taze_dakika', 3));

        $satirlar = DB::table(self::TABLO.' as k')
            ->join('users as u', 'u.id', '=', 'k.user_id')
            ->where('k.reported_at', '>=', $listeEsigi)
            // En taze en üstte: patron haritayı listeyle birlikte okur, sıra rastgele olmamalı.
            ->orderByDesc('k.reported_at')
            ->get(['k.user_id', 'u.name', 'u.role', 'k.lat', 'k.lng', 'k.accuracy_m', 'k.reported_at']);

        $sonuc = [];

        foreach ($satirlar as $satir) {
            $bildirilme = CarbonImmutable::parse((string) $satir->reported_at);

            $sonuc[] = new CanliKonum(
                kullaniciId: (string) $satir->user_id,
                ad: (string) $satir->name,
                rol: (string) $satir->role,
                lat: (float) $satir->lat,
                lng: (float) $satir->lng,
                dogrulukM: $satir->accuracy_m === null ? null : (float) $satir->accuracy_m,
                bildirilme: $bildirilme,
                tazeMi: $bildirilme >= $tazeEsigi,
            );
        }

        return $sonuc;
    }

    /**
     * Eşiği dakika olarak okur. Sıfır/negatif bir env değeri özelliği sessizce bozardı
     * (0 dakikalık pencere = hep boş liste), bu yüzden en az 1'e sabitlenir.
     */
    private function dakika(string $anahtar, int $varsayilan): int
    {
        return max(1, (int) config('konum.'.$anahtar, $varsayilan));
    }
}
