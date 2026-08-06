{{--
    sipario.com.tr · İLETİŞİM (tasarım: _kaynak/web/15-sw-destek.jsx · IletisimSayfa).
    Solda kanallar + künye, sağda form. Formun davranışı ve gerekçesi: site/parca/iletisim-form.blade.php.

    YER TUTUCU BASILMAZ (2026-08-05): künye alanlarının config varsayılanı köşeli parantezlidir
    ("[Şirket unvanı]") — sahte unvan/MERSİS/VKN yazılmaz, ama yer tutucunun KENDİSİ de ekrana
    çıkmamalı. Ziyaretçi "MERSİS [MERSİS no]" yazan bir kutu görürse site yarım kalmış görünür.
    Alt bilgideki dört künye kutusuna uygulanan karar (madde 10) buraya da taşındı: gerçek değeri
    olmayan satır hiç basılmaz, hiçbiri gerçek değilse pano tamamen düşer. Gerçek künye config'e
    girdiği gün kutu kendiliğinden geri gelir — burada değişiklik gerekmez.
    Mevzuat karşılığı kapalı: satıcı künyesi mesafeli satış sözleşmesi + ön bilgilendirme
    formunda duruyor ve alt bilgiden erişiliyor.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat, 'kunye' => $kunye, 'bos' => $bos]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);

    // Künyenin iki satırı ayrı ayrı süzülüyor: unvan/adres gerçekse üst satır, MERSİS/vergi
    // dairesi gerçekse alt satır basılır. İkisi de boşsa pano hiç kurulmaz.
    $kimlik = array_values(array_filter([$kunye['title'] ?? null, $kunye['address'] ?? null], fn ($v) => ! $bos($v)));
    $vergi = array_values(array_filter([
        $bos($kunye['mersis'] ?? null) ? null : 'MERSİS '.$kunye['mersis'],
        $bos($kunye['tax_office'] ?? null) ? null : $kunye['tax_office'],
    ]));
@endphp

<x-layouts.site
    baslik="İletişim — demo talebi ve özel talepler · Sipario"
    aciklama="Sipario ekibiyle konuşun: demo talebi, çok şubeli işletmeler için özel talepler, fiyat ve paket soruları, teknik destek. İşletmenizi anlatın, size uyar mı dürüstçe söyleyelim.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    <section class="blm">
        <div class="kap il-ic">
            <div class="il-sol">
                <span class="blm-kulak mn"><i></i>İletişim</span>
                <h1 class="h1 ic-h1">Önce konuşalım.</h1>
                <p class="gvd b">İşletmenizi anlatın; Sipario size uyar mı, dürüstçe söyleyelim. Uymuyorsa satmıyoruz.</p>

                {{-- Kanal listesi yer tutucular süzüldükten sonra gelir (bkz. _veri.php · kanal);
                     hepsi yer tutucuysa dizi boşalır ve blok hiç basılmaz. --}}
                @if (! empty($sw['kanal']))
                    <div class="il-kanal">
                        @foreach ($sw['kanal'] as $k)
                            <div class="il-k">
                                <span class="il-k-ik"><x-site.ikon :ad="$k['ik']" boy="19" kalin="2" renk="var(--mor)" /></span>
                                <div>
                                    <b>@if($k['href'])<a href="{{ $k['href'] }}">{{ $k['deger'] }}</a>@else{{ $k['deger'] }}@endif</b>
                                    <span class="kucuk">{{ $k['a'] }}</span>
                                </div>
                            </div>
                        @endforeach
                    </div>
                @endif

                @if ($kimlik !== [] || $vergi !== [])
                    <x-site.pano ince duz class="il-adres" sik-ic>
                        <span class="mn">Merkez</span>
                        {{-- Satır-içi boşluklar kaynaktaki IletisimSayfa ile birebir (.il-adres .pano-ic akışı düz). --}}
                        @if ($kimlik !== [])
                            <p class="gvd" style="font-size:15.5px;margin-top:10px">{!! implode('<br>', array_map('e', $kimlik)) !!}</p>
                        @endif
                        @if ($vergi !== [])
                            <p class="kucuk" style="margin-top:8px">{{ implode(' · ', $vergi) }}</p>
                        @endif
                    </x-site.pano>
                @endif
            </div>

            @include('site.parca.iletisim-form')
        </div>
    </section>
</x-layouts.site>
