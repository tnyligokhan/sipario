{{--
    sipario.com.tr · FİYATLANDIRMA (tasarım: _kaynak/web/11-sw-fiyat.jsx · FiyatSayfa).

    FİYATLAR SABİT YAZILMAZ: plan fiyatı/deneme/kota PlanDeposu'dan, ek paketler EkPaketServisi
    kataloğundan okunur (bkz. site/parca/_kur.php). Panelden fiyat değişince bu sayfa kendiliğinden
    güncellenir.

    ── SAYFA GERİ AÇILDI (2026-09-01, kullanıcı kararı) ────────────────────────────────────
    2026-08-05'te bu sayfa menüden çıkarılmış ve `noindex` ile arama motorlarına kapatılmıştı;
    fiyat çağrıları ana sayfanın `#fiyat` çapasına bağlanmıştı. Kullanıcı bu düzeni reddetti
    ("menü hiç mantıklı değil, onepage bir tasarım değil zaten bu") — bkz. components/site/
    ust-menu.blade.php. Sayfa artık menüde duruyor, dizine açık ve site haritasında.

    ⚠️ `noindex` KALDIRILIRKEN İKİ YER BİRLİKTE DEĞİŞTİ: `robots` etiketi ve `routes/web.php`
    içindeki site haritası listesi. Biri kalırsa Google'a çelişkili iki sinyal gider ("haritada
    var ama indeksleme") — OlcumVeSeoTest bunu kilitliyor.

    Ana sayfadaki fiyat ÖZETİ duruyor ve bu sayfayla çakışmıyor: özet tek soruyu cevaplıyor
    ("kaç para"), bu sayfa kalanını (aylık/yıllık, ek paketler, kapsam tablosu, ödeme yolları).
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

<x-layouts.site
    baslik="Fiyatlar | Sipario"
    :aciklama="'Tek plan, tek fiyat. Müşteri ve sipariş sınırı yok, ek kalem çıkmaz. '.$fiyat['deneme'].' gün ücretsiz deneme, kart bilgisi istemiyoruz.'">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
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
