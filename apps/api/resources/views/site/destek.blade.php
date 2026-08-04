{{--
    sipario.com.tr · DESTEK / SSS (tasarım: _kaynak/web/15-sw-destek.jsx · DestekSayfa).
    Kanallar + aranabilir, gruplu sık sorulanlar + alt çağrı bandı.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

<x-layouts.site
    baslik="Destek ve sık sorulan sorular · Sipario"
    aciklama="Sipario destek: telefon, WhatsApp ve e-posta ile gerçek insan. Kurulum, ödeme, iptal ve teknik konularda sık sorulan sorular ve cevapları.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    @include('site.parca.destek-kanal')
    @include('site.parca.destek-sss')
    @include('site.parca.destek-cta')
</x-layouts.site>
