{{--
    Fiyatlandırma · hero + dönem anahtarı + TEK planın yatay levhası
    (11-sw-fiyat.jsx · FiyatSayfa üst bloğu, DonemAnahtar, PlanKart).

    TEK PAKET (2026-08-05): tasarımın ikinci kartı ("Kurumsal · 1.499 ₺'den başlar") kaldırıldı —
    `plans` tablosu tek satırlıdır, Kurumsal diye satılan bir plan yoktur.

    ── YATAY LEVHA (2026-09-01, kullanıcı kararı) ──────────────────────────────────────────
    Dikey plan kartı (`.plan`) ve altındaki mor "ek kurye" bilgi kutusu kaldırıldı; ikisinin
    yerini `x-site.plan-yatay` aldı. Gerekçeler o bileşenin belge başlığında yazılı — özetle:
    karşılaştırılacak ikinci bir plan yokken dikey kart biçimi boşa çalışıyordu, ek kurye notu
    da kararın yanında duran ama kimsenin sormadığı bir istisnaydı; artık kendi satırının içinde.

    Dönem anahtarı Alpine ile ve artık bileşenin İÇİNDE (iki sayfa aynı levhayı basıyor, anahtar
    yalnız bu sayfada isteniyor — `donem` prop'u geçilince kuruluyor). Sunucu YILLIK dönemi basar:
    JavaScript kapalıysa sayfa yıllık fiyatla okunur kalır, boş kutu değil.

    "2 ay hediye" HESAPLANIR (bkz. _kur.php): panelden fiyat değişince rozet kendini düzeltir,
    kazanç bir aydan azsa hiç basılmaz.
--}}
@php
    $p = $sw['plan']['sipario'];
    // Alpine'in dönem anahtarında kullanacağı, sunucuda biçimlenmiş metinler.
    $donemMetin = [
        'yil' => [
            'rakam' => $fiyat['yillikAy'],
            'alt' => 'yıllık ödemede',
            'not' => 'Yılda bir kez '.$fiyat['yillikToplam'].' tahsil edilir · havale veya elden · KDV dahil',
        ],
        'ay' => [
            'rakam' => $fiyat['aylik'],
            'alt' => 'aylık ödemede',
            'not' => 'Her ay '.$fiyat['aylik'].' tahsil edilir · istediğiniz zaman bırakırsınız · KDV dahil',
        ],
    ];
@endphp
<section class="blm fiyat-hero">
    <div class="kap">
        <div class="blm-bas fiyat-bas">
            <span class="blm-kulak mn"><i></i>Fiyatlandırma</span>
            <h1 class="h1">Tek plan, açık fiyat.<br>Büyüdükçe cezalandırmıyoruz.</h1>
            <p class="gvd b">Müşteri, sipariş ya da veri sınırı yok. Ne kadar çalışırsanız çalışın fiyat aynı kalır — sadece kaç kişinin kullandığı değişir.</p>
        </div>

        <x-site.plan-yatay :plan="$p" :fiyat="$fiyat" kimlik="fiyat" :donem="$donemMetin" />
    </div>
</section>
