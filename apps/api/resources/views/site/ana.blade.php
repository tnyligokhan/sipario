{{--
    sipario.com.tr · ANA SAYFA (tasarım: _kaynak/web/09-sw-ana.jsx · AnaSayfa).

    Livewire DEĞİL, düz Blade: içerik statiktir, sunucu durumu taşımaz. Ürün turunun sekmeleri ve
    SSS akordiyonu Alpine ile istemcide çözülür.

    Layout `koyu` kipinde: hero koyu zeminli ve tam genişlikte nav'ın altına akar (<main> "ic"
    sınıfını ALMAZ — bkz. x-layouts.site başlığındaki not).

    Bölümler `site/parca/` altına ayrıldı; sayfa dosyaları 500 satırın altında kalsın diye.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

<x-layouts.site koyu
    baslik="Sipario — Telefon çaldığında müşteriniz ekranda"
    :aciklama="'Sipario gelen numarayı müşteri defterinizle eşleştirir: kim aradı, nerede oturuyor, ne kadar borcu var. Bayiler ve esnaf için sipariş, veresiye ve kurye defteri. '.$fiyat['deneme'].' gün ücretsiz.'">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    @include('site.parca.ana-hero')
    @include('site.parca.ana-kanit')
    @include('site.parca.ana-dert')
    @include('site.parca.ana-tur')
    @include('site.parca.adim')
    @include('site.parca.ana-guvence')
    @include('site.parca.ana-yorum')
    @include('site.parca.ana-fiyat-ozet')
    @include('site.parca.ana-sss-ozet')
    @include('site.parca.son-cagri')
</x-layouts.site>
