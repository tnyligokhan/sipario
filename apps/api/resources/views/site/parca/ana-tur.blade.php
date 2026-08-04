{{--
    Ana sayfa · Ürün turu (09-sw-ana.jsx · TurBlm). Sekmeler Alpine ile; her sekmede maketin başka
    bir ekranı görünür.

    NEDEN x-show (x-if DEĞİL): beş ekranın metni de sunucudan basılıyor. `<template x-if>` kullansaydık
    içerik yalnız JavaScript çalıştıktan sonra DOM'a girerdi — bu bir SATIŞ sayfası, ürün anlatısının
    HTML kaynağında durması gerekiyor. Bedeli, maketin beş kopyasının sayfada bulunması.
--}}
<section class="blm tur-blm" x-data="{ sekme: 'cagri' }">
    <div class="kap">
        <x-site.blm-bas kulak="Ürün turu" baslik="Ekranın kendisi. Ekran görüntüsü değil."
            aciklama="Aşağıdaki telefon çalışan arayüzün ta kendisi — uygulamadaki ölçüler, renkler ve yerleşimle birebir." />

        {{-- varsayilan, yukarıdaki x-data'nın başlangıç değeriyle AYNI olmalı: ilk boyamada
             (Alpine yüklenmeden) da doğru sekme seçili görünsün. --}}
        <x-site.sekmeler model="sekme" varsayilan="cagri" :liste="collect($sw['tur'])->map(fn ($t) => ['k' => $t['k'], 'ad' => $t['ad'], 'ik' => $t['ik']])->all()" />

        <div class="tur-ic">
            <div class="tur-tel">
                @foreach ($sw['tur'] as $t)
                    <div x-show="sekme === '{{ $t['k'] }}'" @if(! $loop->first) x-cloak @endif>
                        <x-site.telefon :ekran="$t['ekran']" :oran="0.66" :cagri="$t['cagri']" />
                    </div>
                @endforeach
            </div>
            <div>
                @foreach ($sw['tur'] as $t)
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
