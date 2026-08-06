{{--
    sipario.com.tr · FİYATLANDIRMA (tasarım: _kaynak/web/11-sw-fiyat.jsx · FiyatSayfa).

    FİYATLAR SABİT YAZILMAZ: plan fiyatı/deneme/kota PlanDeposu'dan, ek paketler EkPaketServisi
    kataloğundan okunur (bkz. site/parca/_kur.php). Panelden fiyat değişince bu sayfa kendiliğinden
    güncellenir.

    GÖSTERİLMİYOR AMA SİLİNMEDİ (2026-08-05 kararı): tek pakete geçildiği için ayrı bir
    "fiyatlandırma" sayfasına gerek kalmadı — fiyat ana sayfada duruyor. Sayfa ve rota çalışır
    halde bırakıldı (linki bilen/kaydeden ulaşabilsin, hesap panelinden gelen bağlantılar kırılmasın)
    ama menüden çıkarıldı ve `noindex` ile arama motorlarına kapatıldı. `follow` bilinçlidir: sayfadan
    çıkan iç bağlantıların değeri korunsun, yalnız bu sayfa dizine girmesin.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

<x-layouts.site
    baslik="Fiyatlandırma — tek plan, açık fiyat · Sipario"
    :aciklama="'Tek plan, açık fiyat: aylık ya da yıllık. Müşteri ve sipariş sınırı yok. Havale/EFT ve elden ödeme. '.$fiyat['deneme'].' gün ücretsiz deneme, kart bilgisi istemiyoruz.'">
    @push('bas')<meta name="robots" content="noindex,follow"><link rel="canonical" href="{{ url()->current() }}">@endpush
    @include('site.parca.fiyat-planlar')
    @include('site.parca.fiyat-hak')
    @include('site.parca.fiyat-karsilastir')
    @include('site.parca.fiyat-odeme-guven')

    {{-- Ödeme soruları: SSS'in "Ödeme" grubu (11-sw-fiyat.jsx · FiyatSayfa). --}}
    <section class="blm">
        <div class="kap sss-kap">
            <x-site.blm-bas kulak="Ödeme soruları" baslik="Faturayı kim keser, iptal nasıl olur?" />
            <x-site.sss :liste="$sw['sss'][1]['l']" acik-var />
        </div>
    </section>

    @include('site.parca.son-cagri')
</x-layouts.site>
