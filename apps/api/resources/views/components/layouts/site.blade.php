{{--
    site — sipario.com.tr genel site layout'u: üst menü + slot + alt bilgi.
    `koyu`: ana sayfadaki gibi koyu/transparan hero altında şeffaf nav (bkz. 17-sw-uygulama.jsx'teki
    `document.body.dataset.koyu = sayfa === 'ana' ? '1' : ''`). koyu=true iken <main> "ic" sınıfını
    ALMAZ (hero tam genişlikte nav'ın altına akar); koyu=false iken "ic" sınıfı üst boşluğu verir.
    `oturum`: bayi oturum durumu — üst menüye iletilir, bu layout kimlik doğrulamayı sorgulamaz.
--}}
@props(['baslik' => 'Sipario — Telefon çaldığında müşteriniz ekranda', 'koyu' => false, 'oturum' => false])
<!doctype html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $baslik }}</title>
    <link rel="stylesheet" href="{{ asset('css/site.css') }}">
    @livewireStyles
</head>
<body @if($koyu) data-koyu="1" @endif>
    <x-site.ust-menu :koyu="$koyu" :oturum="$oturum" />
    <main @class(['ic' => !$koyu])>
        {{ $slot }}
    </main>
    <x-site.alt-bilgi />
    <x-site.bildirim />
    @livewireScripts
</body>
</html>
