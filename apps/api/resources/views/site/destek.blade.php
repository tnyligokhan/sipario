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

{{-- Başlık sadeleşti (2026-09-01; gerekçe site/ana.blade.php'de). Sayfanın adı "Destek" —
     başlığa üç anahtar kelime daha sıkıştırmak, arama sonucunda sayfanın ne olduğunu gizliyordu. --}}
<x-layouts.site
    baslik="Destek ve sık sorulanlar | Sipario"
    aciklama="Kurulum, ödeme ve teknik sorularınızın cevapları: veresiye defteri nasıl işler, internet kesilince ne olur, müşteri listesi nasıl aktarılır. Yanıtı insan yazıyor.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    @include('site.parca.destek-kanal')
    @include('site.parca.destek-sss')
    @include('site.parca.destek-cta')
</x-layouts.site>
