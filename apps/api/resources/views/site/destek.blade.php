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

{{-- Birincil kelime: "veresiye takip programı" (docs/seo-anahtar-kelimeler.md). Sayfanın SSS
     içeriği zaten bu kelimenin etrafında dönüyor; başlık onu görünür kılıyor. --}}
<x-layouts.site
    baslik="Veresiye takip programı — destek ve sık sorulanlar · Sipario"
    aciklama="Kurulum, ödeme, iptal ve teknik sorularınızın cevapları. Veresiye defteri nasıl işler, internet kesilince ne olur, müşteri listesi nasıl aktarılır — telefonu bot değil insan açıyor.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    @include('site.parca.destek-kanal')
    @include('site.parca.destek-sss')
    @include('site.parca.destek-cta')
</x-layouts.site>
