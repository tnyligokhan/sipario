{{--
    KimlikKabuk — giriş/kayıt/parola sıfırlama sayfalarının iki panelli kabuğu. site-ciplak layout'u
    içinde kullanılır (menüsüz). Soldaki istatistikler SW_KANIT ile birebir aynıdır (design_handoff
    _kaynak/web/05-sw-veri.jsx) — sayfa içeriği değil, bileşenin kendi içine gömülü tasarım verisidir.
--}}
@props(['kulak' => null, 'baslik', 'aciklama' => null, 'genis' => false, 'altYazi' => null])
<main class="kimlik">
    <aside class="kimlik-sol gece">
        <a class="kimlik-marka" href="{{ Route::has('site.ana') ? route('site.ana') : url('/') }}">
            <x-site.marka boy="38" koyu />
        </a>
        <div class="kimlik-govde">
            <p class="h2 kimlik-soz">"Defteri bıraktık. Ay sonunda tahsil edemediğimiz para 12 binden 3 bine düştü."</p>
            <div class="kimlik-kim">
                <b>Hasan Yıldırım</b>
                <span class="kucuk">Yıldırım Su · Antalya</span>
            </div>
        </div>
        <div class="kimlik-alt">
            @foreach ([['1.240', 'işletme'], ['6 dk', 'sipariş başına'], ['%31', 'daha az kayıp']] as [$v, $b])
                <div class="kimlik-k">
                    <b>{{ $v }}</b><span class="mn k">{{ $b }}</span>
                </div>
            @endforeach
        </div>
    </aside>
    <section class="kimlik-sag">
        <div class="kimlik-form {{ $genis ? 'genis' : '' }}">
            @if($kulak)<span class="blm-kulak mn"><i></i>{{ $kulak }}</span>@endif
            <h1 class="h1 kimlik-h1">{{ $baslik }}</h1>
            @if($aciklama)<p class="gvd kimlik-lead">{{ $aciklama }}</p>@endif
            {{ $slot }}
        </div>
        @if($altYazi)<div class="kimlik-dip kucuk">{{ $altYazi }}</div>@endif
    </section>
</main>
