{{--
    Ana sayfa · Ürün turu (09-sw-ana.jsx · TurBlm). Sekmeler Alpine ile; her sekmede maketin başka
    bir ekranı görünür.

    NEDEN x-show (x-if DEĞİL): ekranların metni de sunucudan basılıyor. `<template x-if>`
    kullansaydık içerik yalnız JavaScript çalıştıktan sonra DOM'a girerdi — bu bir SATIŞ sayfası,
    ürün anlatısının HTML kaynağında durması gerekiyor. Bedeli, maketin birden çok kopyasının
    sayfada bulunması.

    ── 2026-08-19 · BEŞ SEKME → ÜÇ ─────────────────────────────────────────────────────────
    Ana sayfa, ziyaretçiye BEŞ ekranı sekme sekme gezdiriyordu; aynı beş ekran Özellikler
    sayfasında bir kez daha, bu kez daha uzun anlatılıyordu. Yani siteyi baştan sona okuyan
    esnaf aynı şeyi iki kez okuyordu.

    Karar: ana sayfa ürünün ÜÇ temel işini gösterir (arayan tanıma · veresiye · gün sonu);
    sipariş akışı ve kurye/rota Özellikler sayfasında kalır. Seçim keyfi değil — bu üçü,
    ürünün var oluş sebebi (arayan tanıma), en çok kullanılan defteri (veresiye) ve günü
    kapatan işlem (gün sonu). Sipariş akışı zaten arayan tanıma kartının içinde görünüyor,
    kurye ise tek kişilik bayilerin hiç kullanmadığı bir özellik.

    Hangi sekmelerin görüneceği `$sw['tur']` sırasına değil, aşağıdaki `ANA_SEKMELER` listesine
    bağlı: veri dosyası beş ekranın tamamını taşımaya devam ediyor (Özellikler onu okuyor),
    burada yalnız süzülüyor. Ekran eklemek/çıkarmak için tek satır.

    ── BAŞLIK KALDIRILDI ───────────────────────────────────────────────────────────────────
    Eski başlık "Ekranın kendisi. Ekran görüntüsü değil." + açıklaması "uygulamadaki ölçüler,
    renkler ve yerleşimle birebir" idi. Bu bir GELİŞTİRİCİ övüncüdür: maketin gerçek arayüzle
    piksel uyumu bizim için önemli, tezgâhın arkasındaki adam için hiçbir anlam taşımıyor —
    üstelik "bu ekran görüntüsü değil" demek, aklına hiç gelmemiş bir şüpheyi ona hediye eder.
    Yerine ne göreceğini söyleyen düz bir başlık kondu.
--}}
@php
    // Ana sayfada gösterilecek ekranlar. Veri dosyası (site/parca/_veri.php · 'tur') beşini de
    // taşır; Özellikler sayfası tamamını basar.
    $anaSekmeler = ['cagri', 'veresiye', 'gunsonu'];
    $tur = array_values(array_filter($sw['tur'], fn (array $t): bool => in_array($t['k'], $anaSekmeler, true)));
@endphp
<section class="blm tur-blm" x-data="{ sekme: 'cagri' }">
    <div class="kap">
        <x-site.blm-bas baslik="Uygulama böyle görünüyor."
            aciklama="Günün büyük kısmı bu üç ekranda geçiyor." />

        {{-- varsayilan, yukarıdaki x-data'nın başlangıç değeriyle AYNI olmalı: ilk boyamada
             (Alpine yüklenmeden) da doğru sekme seçili görünsün. --}}
        <x-site.sekmeler model="sekme" varsayilan="cagri" :liste="collect($tur)->map(fn ($t) => ['k' => $t['k'], 'ad' => $t['ad'], 'ik' => $t['ik']])->all()" />

        <div class="tur-ic">
            <div class="tur-tel">
                @foreach ($tur as $t)
                    <div x-show="sekme === '{{ $t['k'] }}'" @if(! $loop->first) x-cloak @endif>
                        <x-site.telefon :ekran="$t['ekran']" :oran="0.66" :cagri="$t['cagri']" />
                    </div>
                @endforeach
            </div>
            <div>
                @foreach ($tur as $t)
                    <div class="tur-metin" role="tabpanel" aria-label="{{ $t['ad'] }}"
                        x-show="sekme === '{{ $t['k'] }}'" @if(! $loop->first) x-cloak @endif>
                        <h3 class="h2">{{ $t['bas'] }}</h3>
                        <p class="gvd b">{{ $t['a'] }}</p>
                        <ul class="tur-liste">
                            @foreach ($t['ozet'] as $o)
                                <li>
                                    <span class="tur-tik"><x-site.ikon ad="onay" boy="13" kalin="3" renk="#fff" /></span>{{ $o }}
                                </li>
                            @endforeach
                        </ul>
                    </div>
                @endforeach
            </div>
        </div>

    </div>
</section>
