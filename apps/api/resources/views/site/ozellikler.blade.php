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

{{-- Birincil kelime: "arayan tanıma programı" (docs/seo-anahtar-kelimeler.md). Ürünün varlık
     sebebi ve rakiplerde olmayan tek şey; başlıkta ÖNDE durması bu yüzden. --}}
<x-layouts.site
    baslik="Arayan tanıma programı, veresiye defteri ve kurye takibi · Sipario"
    aciklama="Gelen aramada müşteri kartı ekranda: adı, adresi, borcu, son siparişi. Veresiye defteri, sipariş akışı, kurye ve rota, gün sonu kasa — internet gitse de çalışır.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    @include('site.parca.ozellik-hero')
    @include('site.parca.ozellik-split')
    @include('site.parca.ozellik-gun')
    @include('site.parca.ozellik-ek')
    @include('site.parca.adim')
    @include('site.parca.son-cagri')
</x-layouts.site>
