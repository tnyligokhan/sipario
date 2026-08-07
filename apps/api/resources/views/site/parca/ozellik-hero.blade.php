{{--
    Özellikler · hero (10-sw-ozellik.jsx · OzellikHero). Deneme süresi PlanDeposu'dan.

    İkinci düğme eskiden /fiyatlar'a gidiyordu; tek pakete geçişte o sayfa gösterilmiyor
    (bkz. site/fiyatlar.blade.php başlığı). Fiyat artık ana sayfadaki `#fiyat` bölümünde.
--}}
<section class="blm ic-hero">
    <div class="kap ic-hero-ic">
        <div>
            <span class="blm-kulak mn"><i></i>Özellikler</span>
            <h1 class="h1 ic-h1">Tezgâhın arkasındaki<br>bütün defterler, tek ekranda.</h1>
            <p class="gvd b ic-lead">Sipario bir “sipariş uygulaması” değil. Telefonu açtığınız andan akşam kasayı kapattığınız ana kadar geçen işin tamamı.</p>
            <div class="dg-grup" style="margin-top:30px">
                <a class="dg dg-a" href="{{ route('subscription.register') }}">{{ $fiyat['deneme'] }} gün ücretsiz dene<x-site.ikon ad="ok" boy="18" kalin="2.2" /></a>
                <a class="dg dg-c" href="{{ route('site.ana') }}#fiyat">Fiyata bak</a>
            </div>
        </div>
        <div class="ic-hero-sag">
            <x-site.telefon ekran="ana" :oran="0.56" />
        </div>
    </div>
</section>
