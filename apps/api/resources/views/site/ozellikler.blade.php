{{--
    sipario.com.tr · ÖZELLİKLER (tasarım: _kaynak/web/10-sw-ozellik.jsx · OzellikSayfa).
    Hero + beş dönüşümlü anlatı bölümü + "bir gün" zaman çizelgesi + ek özellikler + kurulum + son çağrı.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

<x-layouts.site
    baslik="Özellikler — arayan tanıma, veresiye defteri, kurye ve gün sonu · Sipario"
    aciklama="Arayan tanıma, veresiye defteri, sipariş akışı, kurye ve rota, gün sonu kasa. Sipario'nun tezgâhın arkasında yaptığı işin tamamı — çevrimdışı da çalışır.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    @include('site.parca.ozellik-hero')
    @include('site.parca.ozellik-split')
    @include('site.parca.ozellik-gun')
    @include('site.parca.ozellik-ek')
    @include('site.parca.adim')
    @include('site.parca.son-cagri')
</x-layouts.site>
