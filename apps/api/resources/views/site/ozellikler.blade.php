{{--
    sipario.com.tr · ÖZELLİKLER

    Hero (maketsiz, sola yaslı) → beş alan (kaydırdıkça yığılan levhalar) → küçük işler → son çağrı.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

<x-layouts.site
    baslik="Özellikler | Sipario"
    aciklama="Arayan tanıma, sipariş alma, kurye ve rota, veresiye defteri, gün sonu kasa. Sipario'nun beş alanı, ne yaptıklarıyla birlikte.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    @include('site.parca.ozellik-hero')
    @include('site.parca.ozellik-split')
    @include('site.parca.ozellik-ek')
    @include('site.parca.son-cagri')
</x-layouts.site>
