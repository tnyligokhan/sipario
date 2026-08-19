{{--
    UstMenu — sabit üst menü. `koyu`: ana sayfa gibi koyu hero üstünde şeffaf/açık renkli başlar
    (bkz. site.css body[data-koyu="1"] .ust kuralları). `oturum`: bayi oturumu açıksa "Hesabım"
    gösterir; kapalıysa Giriş/Ücretsiz dene gösterir — sayfa/layout tarafından geçilir, bu bileşen
    kimlik doğrulamayı KENDİSİ sorgulamaz (layout'un neden oturum anahtarına baktığı ve
    `Auth::check()`in bu sayfalarda neden yalan söylediği: components/layouts/site.blade.php).

    Rota adları henüz açılmamışsa (site.* — bu dalgada tanımlanacak) bağlantı sessizce atlanır;
    depo çökmez.
--}}
@props(['koyu' => false, 'oturum' => false])
@php
    /*
     * MENÜDE YALNIZ İKİ SAYFA (2026-08-05 kullanıcı kararı: "gereksiz sayfaları menüde değil
     * altbilgide gösterelim"). Menü bir keşif aracıdır, site haritası değil: dört eşit ağırlıklı
     * bağlantı ziyaretçinin dikkatini sağdaki "Ücretsiz dene" düğmesinden çalıyordu.
     *
     * ÇIKARILANLAR ve neden:
     *  - Fiyatlandırma: sayfa DURUYOR, menüden kalktı. Fiyat zaten ana sayfanın kendi özet
     *    bölümünde ve alt bilgide; menüde ikinci kez durması, ziyaretçiyi ürünü tanımadan
     *    fiyat sayfasına yolluyordu (bu kararın ikinci yarısı `fiyat` ajanında).
     *  - İletişim: alt bilgiye indi. İletişim bir SONUÇ sayfasıdır (ürünü beğendikten sonra
     *    aranır); alt bilgi tam olarak orada, sayfanın sonundadır.
     *
     * KALANLAR: Özellikler (ürün ne yapıyor) + Destek (satın almadan önceki asıl itiraz:
     * "bozulursa kim bakacak"). İkisi de satın alma kararının önündeki engeli kaldırır.
     */
    $menu = [
        ['site.ozellikler', 'Özellikler'],
        ['site.destek', 'Destek'],
    ];
    $anaHref = Route::has('site.ana') ? route('site.ana') : url('/');
@endphp
<header class="ust" x-data="ustMenu" :class="{ kaydi: kaydi, acik: acik }">
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
                {{--
                    ÇIKIŞ FORMDUR, BAĞLANTI DEĞİL — pazarlıksız. Düz bir <a href> ile çıkış, GET
                    olduğu için istemsiz tetiklenebilir: tarayıcının bağlantı önceden getirmesi
                    (prefetch), bir eklenti taraması ya da üçüncü taraf sayfadaki
                    `<img src="…/cikis">` kullanıcıyı haberi olmadan oturumdan atar. Form + `@csrf`
                    ile istek POST olur ve token'sız üçüncü taraf isteği `VerifyCsrfToken`e takılır.
                    (`panel.logout` da aynı desende; `Hesap::cikis()` ise Livewire eylemi olduğu
                    için korumayı Livewire'ın kendi CSRF katmanından alıyor.)

                    Üst menü Livewire bileşeni DEĞİL — her sayfada basılan düz Blade. Bu yüzden
                    `Hesap::cikis()` buradan çağrılamaz; adanmış POST rotası en ucuz doğru yol.
                    Hesap panelindeki çıkış KALDIRILMADI, ikisi bir arada duruyor.
                --}}
                @if(Route::has('site.cikis'))
                    <form method="POST" action="{{ route('site.cikis') }}">
                        @csrf
                        <button type="submit" class="dg dg-d k"><x-site.ikon ad="cikis" boy="17" kalin="2.1" />Çıkış</button>
                    </form>
                @endif
            @else
                @if(Route::has('subscription.login'))
                    <a href="{{ route('subscription.login') }}" class="dg dg-d k">Giriş yap</a>
                @endif
                @if(Route::has('subscription.register'))
                    <a href="{{ route('subscription.register') }}" class="dg dg-a k" data-olcum="sipario_deneme_tik" data-olcum-etiket="ust-menu">Ücretsiz dene</a>
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
                {{-- Aynı form/POST gerekçesi masaüstü bloğunda yazılı. --}}
                @if(Route::has('site.cikis'))
                    <form method="POST" action="{{ route('site.cikis') }}">
                        @csrf
                        <button type="submit" class="dg dg-c tam">Çıkış</button>
                    </form>
                @endif
            @else
                @if(Route::has('subscription.login'))
                    <a href="{{ route('subscription.login') }}" class="dg dg-c tam">Giriş yap</a>
                @endif
                @if(Route::has('subscription.register'))
                    <a href="{{ route('subscription.register') }}" class="dg dg-a tam" data-olcum="sipario_deneme_tik" data-olcum-etiket="mobil-menu">Ücretsiz dene</a>
                @endif
            @endif
        </div>
    </div>
</header>
