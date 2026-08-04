{{--
    Destek · iletişim kanalları (15-sw-destek.jsx · DestekSayfa üst bloğu).

    Numaralar/adres KÖŞELİ PARANTEZ yer tutucudur; gerçek künye netleşmedi (aynı biçim
    x-site.alt-bilgi ve legal/docs/* içinde de kullanılıyor). Yer tutucu duruyorken tel:/mailto:
    bağlantısı BASILMAZ — tıklanınca hiçbir yere gitmeyen bir bağlantı, bağlantı olmamasından
    kötüdür. Gerçek değer girildiğinde `href` dolar ve bağlantı kendiliğinden açılır.
--}}
<section class="blm kisa">
    <div class="kap">
        <div class="blm-bas">
            <span class="blm-kulak mn"><i></i>Destek</span>
            <h1 class="h1">Takıldığınız yerde<br>insan var.</h1>
            <p class="gvd b">Telefonu bot açmıyor. Aynı ekip, aynı numara — çoğu soru ilk aramada çözülüyor.</p>
        </div>
        <div class="kanal-grid">
            @foreach ($sw['kanal'] as $k)
                <x-site.pano class="kanal" :ince="! $loop->first">
                    <span class="kanal-ik"><x-site.ikon :ad="$k['ik']" boy="21" kalin="2" renk="var(--mor)" /></span>
                    <span class="mn">{{ $k['t'] }}</span>
                    <b class="h3 kanal-v">
                        @if ($k['href'])<a href="{{ $k['href'] }}">{{ $k['deger'] }}</a>@else{{ $k['deger'] }}@endif
                    </b>
                    <p class="kucuk">{{ $k['a'] }}</p>
                </x-site.pano>
            @endforeach
        </div>
    </div>
</section>
