<?php

use App\Abonelik\EkPaketServisi;
use App\Abonelik\PlanDeposu;
use App\Models\AddonPackage;

/*
 * GENEL SİTE — sayfa kurulumu. Her sayfanın başında bir kez çağrılır:
 *
 *   @inject('planlar', 'App\Abonelik\PlanDeposu')
 *   @inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
 *   @php(['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
 *        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler))
 *
 * NEDEN BURADA: fiyat, deneme süresi ve kotalar PANELDEN DEĞİŞİR (plans tablosu · PlanDeposu).
 * Sitede sabit yazılırsa panel fiyatı değiştirdiği gün site yalan söyler. Ek paket fiyatları da
 * aynı sebeple katalogdan (addon_packages · EkPaketServisi) okunur.
 *
 * NEDEN @inject (view composer DEĞİL): rota `Route::view()`, yani araya girecek bir denetleyici yok;
 * view composer ise bir ServiceProvider gerektirirdi (app/** bu dalgada başka bir ajanın alanı).
 * @inject aynı işi görünümün kendi içinde, tek satırda yapar.
 */

return function (PlanDeposu $planlar, EkPaketServisi $ekPaketler): array {
    // Kuruş → "1.234 ₺". Tam liraysa ondalık basılmaz (tasarımdaki `tl()` davranışı).
    $tl = fn (int $kurus): string => number_format($kurus / 100, $kurus % 100 === 0 ? 0 : 2, ',', '.').' ₺';

    $aylikKurus = $planlar->aylikKurus();
    $yillikKurus = $planlar->yillikKurus();
    $deneme = $planlar->denemeGun();
    $kontor = $planlar->rotaKontoruAylik();
    $kurye = $planlar->kuryeLimiti();

    // Yıllık ödemenin AYLIK karşılığı — tasarımın "499 ₺ / ay · yıllık ödemede" gösterimi.
    $yillikAyKurus = (int) round($yillikKurus / 12);

    // "2 ay hediye" rozeti HESAPLANIR. Panelden fiyat değişince rozet kendini düzeltir; kazanç
    // bir aydan azsa rozet hiç basılmaz (yoksa okuyucuya olmayan bir indirim vaat edilir).
    $hediyeAy = $aylikKurus > 0 ? (int) floor(($aylikKurus * 12 - $yillikKurus) / $aylikKurus) : 0;

    $satistaki = $ekPaketler->paketler(true);

    /*
     * Oto-sıralama hak paketleri. "En avantajlı" rozeti HAK BAŞINA en ucuz pakete gider —
     * etiketin sözlük anlamı bu. (Tasarımın örnek verisinde rozet ortadaki 250'lik paketteydi,
     * oysa aynı veride hak başına en ucuz olan 500'lüktü; katalog değiştikçe elle bakım
     * gerektirmesin diye hesaplanıyor.)
     */
    $kontorPaketleri = $satistaki
        ->where('type', AddonPackage::TYPE_CREDITS)
        ->sortBy('quantity')
        ->map(fn (AddonPackage $p) => [
            // id: ödeme ekranına ?tur=paket&paket=<id> ile geçilir (Subscribe::mount).
            'id' => $p->id,
            'adet' => $p->quantity,
            'fiyat' => $tl($p->price_kurus),
            'birim' => number_format($p->price_kurus / 100 / max(1, $p->quantity), 2, ',', '.').' ₺',
            'birimKurus' => $p->quantity > 0 ? $p->price_kurus / $p->quantity : PHP_INT_MAX,
        ])
        ->values()
        ->all();

    $enUcuzBirim = $kontorPaketleri === [] ? null : min(array_column($kontorPaketleri, 'birimKurus'));
    foreach ($kontorPaketleri as $i => $p) {
        $kontorPaketleri[$i]['iyi'] = $enUcuzBirim !== null && $p['birimKurus'] === $enUcuzBirim;
    }

    /*
     * Ek kurye hesabı. Tasarım "99 ₺/ay" diyordu; katalogda bunun karşılığı YOK ve ek paket bir
     * SÜRE değil KAPASİTE satışıdır (EkPaketServisi: kota artışı kalıcıdır, aylık yenilenmez).
     * Katalog esas alındı — tek kurye ekleyen en küçük paket okunur.
     */
    $kuryePaketleri = $satistaki
        ->where('type', AddonPackage::TYPE_COURIER)
        ->sortBy('quantity')
        ->map(fn (AddonPackage $p) => ['adet' => $p->quantity, 'fiyat' => $tl($p->price_kurus)])
        ->values()
        ->all();

    $kuryePaketi = $satistaki
        ->where('type', AddonPackage::TYPE_COURIER)
        ->sortBy('quantity')
        ->first();

    $ekKuryeKisa = $kuryePaketi ? $tl($kuryePaketi->price_kurus) : null;
    $ekKuryeTl = $ekKuryeKisa === null
        ? 'talep üzerine'
        : ($kuryePaketi->quantity === 1
            ? $ekKuryeKisa.' · tek seferlik'
            : $kuryePaketi->quantity.' hesap '.$ekKuryeKisa.' · tek seferlik');

    /*
     * ŞİRKET KÜNYESİ — config('subscription.company'). Unvan/adres/MERSİS/telefon/e-posta üç yerde
     * birden geçiyor (alt bilgi, iletişim sayfası, hukuk metinleri); tek noktadan okunmazsa gerçek
     * değerler geldiği gün biri bayat kalır.
     *
     * YER TUTUCU TESPİTİ: config varsayılanları KÖŞELİ PARANTEZLİdir ("[Telefon]"). Böyle bir değer
     * gerçek veri değildir — üzerine `tel:`/`mailto:` bağlantısı basmak, tıklanınca hiçbir yere
     * gitmeyen bir bağlantı üretir. `bos()` bunu ayırt eder; çağıran taraf yer tutucuyu düz metin
     * basar, gerçek değeri bağlantıya çevirir.
     */
    $kunye = config('subscription.company', []);
    $bos = fn (?string $v): bool => $v === null || trim($v) === '' || str_starts_with(trim($v), '[');

    $sw = (require __DIR__.'/_veri.php')([
        'deneme' => $deneme,
        'kontor' => $kontor,
        'kurye' => $kurye,
        'ekKuryeTl' => $ekKuryeTl,
        'ekKuryeKisa' => $ekKuryeKisa ?? '—',
        // Katalogda kurye paketi VAR MI: fiyata bağlı cümleler yoksa hiç kurulmasın (uydurma fiyat yok).
        'ekKuryeVar' => $ekKuryeKisa !== null,
        'kunye' => $kunye,
        'bos' => $bos,
    ]);

    return [
        'sw' => $sw,
        // Ham künye: iletişim sayfasının "Merkez" panosu bunu doğrudan basar.
        'kunye' => $kunye,
        /*
         * Yer tutucu süzgeci GÖRÜNÜMLERE de açık: künyeyi ham basan tek yer iletişim sayfası ve
         * orada da "[Şirket unvanı]" gibi kırık kutular ekrana çıkmamalı (alt bilgide aynı karar
         * uygulandı). Tanımı ikinci kez yazmak yerine buradan geçiyor — süzgeç değişirse iki yer
         * birden değişsin.
         */
        'bos' => $bos,
        // ⚠️ TEMSİLİ (uydurma) veri — dosyanın başındaki uyarıyı okuyun.
        'tmsl' => require __DIR__.'/_temsili-veri.php',
        'tl' => $tl,
        'fiyat' => [
            'aylik' => $tl($aylikKurus),
            'yillikAy' => $tl($yillikAyKurus),
            'yillikToplam' => $tl($yillikKurus),
            'hediyeAy' => $hediyeAy,
            'deneme' => $deneme,
            'kontor' => $kontor,
            'kurye' => $kurye,
            'ekKuryeTl' => $ekKuryeTl,
            'ekKuryeKisa' => $ekKuryeKisa,
            'ekKuryeAdet' => $kuryePaketi?->quantity,
            // Satıştaki BÜTÜN kurye paketleri (ana sayfa + fiyat sayfası aynı listeyi basar).
            'kuryePaketleri' => $kuryePaketleri,
            'kontorPaketleri' => $kontorPaketleri,
        ],
    ];
};
