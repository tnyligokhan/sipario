{{--
    sipario.com.tr · İLETİŞİM (tasarım: _kaynak/web/15-sw-destek.jsx · IletisimSayfa).
    Solda kanallar + künye, sağda form. Formun davranışı ve gerekçesi: site/parca/iletisim-form.blade.php.

    Künye alanları KÖŞELİ PARANTEZ yer tutucudur — sahte unvan/MERSİS/VKN yazılmaz
    (x-site.alt-bilgi ve legal/docs/* aynı biçimi kullanıyor; gerçek künye netleşince hepsi birlikte dolar).
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat, 'kunye' => $kunye]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

<x-layouts.site
    baslik="İletişim — demo talebi ve kurumsal teklif · Sipario"
    aciklama="Sipario ekibiyle konuşun: demo talebi, kurumsal teklif, fiyat ve paket soruları, teknik destek. İşletmenizi anlatın, size uyar mı dürüstçe söyleyelim.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    <section class="blm">
        <div class="kap il-ic">
            <div class="il-sol">
                <span class="blm-kulak mn"><i></i>İletişim</span>
                <h1 class="h1 ic-h1">Önce konuşalım.</h1>
                <p class="gvd b">İşletmenizi anlatın; Sipario size uyar mı, dürüstçe söyleyelim. Uymuyorsa satmıyoruz.</p>

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

                <x-site.pano ince duz class="il-adres" sik-ic>
                    <span class="mn">Merkez</span>
                    {{-- Satır-içi boşluklar kaynaktaki IletisimSayfa ile birebir (.il-adres .pano-ic akışı düz). --}}
                    <p class="gvd" style="font-size:15.5px;margin-top:10px">{{ $kunye['title'] }}<br>{{ $kunye['address'] }}</p>
                    <p class="kucuk" style="margin-top:8px">MERSİS {{ $kunye['mersis'] }} · {{ $kunye['tax_office'] }}</p>
                </x-site.pano>
            </div>

            @include('site.parca.iletisim-form')
        </div>
    </section>
</x-layouts.site>
