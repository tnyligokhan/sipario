{{--
    Özellikler · hero. Sola yaslı, maketsiz.

    Maket YOK ve bu bilinçli: ekran görüntüsünün yeri ana sayfanın hero'su ve ürün turu. Bu sayfa
    ne yaptığını anlatır; her bölümün yanına bir telefon çerçevesi koymak aynı nesneyi altı kez
    göstermekten başka bir şey yapmıyordu.

    Alt şerit, beş alanın çapaları — sayfa uzun, giriş noktası gerekiyor.
--}}
<section class="blm kisa oz-hero">
    <div class="kap oz-hero-ic">
        <span class="blm-kulak mn"><i></i>Özellikler</span>
        <h1 class="h1">Siparişi alan da, yolu düzenleyen de, defteri tutan da aynı uygulama.</h1>
        <p class="gvd b oz-hero-alt">Telefon çaldığı andan kasayı kapattığınız ana kadar geçen işin tamamı beş başlıkta.</p>
        <div class="dg-grup oz-hero-dg">
            <a class="dg dg-a" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="ozellik-hero">{{ $fiyat['deneme'] }} gün ücretsiz dene<x-site.ikon ad="ok" boy="18" kalin="2.2" /></a>
            <a class="dg dg-c" href="{{ route('site.fiyatlar') }}">Fiyata bak</a>
        </div>
        <nav class="oz-capa" aria-label="Sayfa içi bölümler">
            @foreach ($sw['tur'] as $t)
                <a href="#{{ $t['k'] }}"><x-site.ikon :ad="$t['ik']" boy="16" kalin="2" />{{ $t['ad'] }}</a>
            @endforeach
        </nav>
    </div>
</section>
