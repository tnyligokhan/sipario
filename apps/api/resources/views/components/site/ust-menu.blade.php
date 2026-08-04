{{--
    UstMenu — sabit üst menü. `koyu`: ana sayfa gibi koyu hero üstünde şeffaf/açık renkli başlar
    (bkz. site.css body[data-koyu="1"] .ust kuralları). `oturum`: bayi oturumu açıksa "Hesabım"
    gösterir; kapalıysa Giriş/Ücretsiz dene gösterir — sayfa/layout tarafından geçilir, bu bileşen
    kimlik doğrulamayı KENDİSİ sorgulamaz.

    Rota adları henüz açılmamışsa (site.* — bu dalgada tanımlanacak) bağlantı sessizce atlanır;
    depo çökmez.
--}}
@props(['koyu' => false, 'oturum' => false])
@php
    $menu = [
        ['site.ozellikler', 'Özellikler'],
        ['site.fiyatlar', 'Fiyatlandırma'],
        ['site.destek', 'Destek'],
        ['site.iletisim', 'İletişim'],
    ];
    $anaHref = \Illuminate\Support\Facades\Route::has('site.ana') ? route('site.ana') : url('/');
@endphp
<header class="ust" x-data="{ kaydi: false, acik: false }"
    x-init="kaydi = window.scrollY > 12; window.addEventListener('scroll', () => kaydi = window.scrollY > 12, { passive: true })"
    :class="{ kaydi: kaydi, acik: acik }">
    <div class="kap ust-ic">
        <a class="ust-marka" href="{{ $anaHref }}" aria-label="Sipario ana sayfa">
            <x-site.marka :koyu="$koyu" />
        </a>
        <nav class="ust-nav" aria-label="Ana menü">
            @foreach($menu as [$ad, $etiket])
                @if(Route::has($ad))
                    <a href="{{ route($ad) }}" class="ust-l @if(request()->routeIs($ad)) on @endif">{{ $etiket }}</a>
                @endif
            @endforeach
        </nav>
        <div class="ust-sag">
            @if($oturum)
                @if(Route::has('site.hesap'))
                    <a href="{{ route('site.hesap') }}" class="dg dg-b k"><x-site.ikon ad="musteri" boy="17" kalin="2.1" />Hesabım</a>
                @endif
            @else
                @if(Route::has('subscription.login'))
                    <a href="{{ route('subscription.login') }}" class="dg dg-d k">Giriş yap</a>
                @endif
                @if(Route::has('subscription.register'))
                    <a href="{{ route('subscription.register') }}" class="dg dg-a k">Ücretsiz dene</a>
                @endif
            @endif
        </div>
        <button type="button" class="ust-acar" @click="acik = !acik" :aria-expanded="acik" aria-label="Menü">
            <x-site.ikon ad="menu" boy="22" kalin="2.1" x-show="!acik" />
            <x-site.ikon ad="kapat" boy="22" kalin="2.1" x-show="acik" x-cloak />
        </button>
    </div>
    <div class="ust-mobil">
        @foreach($menu as [$ad, $etiket])
            @if(Route::has($ad))
                <a href="{{ route($ad) }}" class="ust-ml">{{ $etiket }}<x-site.ikon ad="sag" boy="18" kalin="2" /></a>
            @endif
        @endforeach
        <div class="ust-mobil-alt">
            @if($oturum)
                @if(Route::has('site.hesap'))
                    <a href="{{ route('site.hesap') }}" class="dg dg-b tam">Hesabım</a>
                @endif
            @else
                @if(Route::has('subscription.login'))
                    <a href="{{ route('subscription.login') }}" class="dg dg-c tam">Giriş yap</a>
                @endif
                @if(Route::has('subscription.register'))
                    <a href="{{ route('subscription.register') }}" class="dg dg-a tam">Ücretsiz dene</a>
                @endif
            @endif
        </div>
    </div>
</header>
