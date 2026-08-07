{{--
    site-ciplak — menüsüz layout: giriş, kayıt, parola sıfırlama, ödeme ekranları.
    Bu ekranlarda üst menü ve alt bilgi bilinçli olarak yok (KimlikKabuk / Ödeme kendi kabuğunu çizer).
--}}
@props(['baslik' => 'Sipario'])
<!doctype html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $baslik }}</title>
    <link rel="stylesheet" href="{{ asset('css/site.css') }}">
    @livewireStyles
</head>
<body>
    {{ $slot }}
    <x-site.bildirim />
    {{-- bkz. layouts/site.blade.php — sıra ve gerekçe aynı. --}}
    <script src="{{ asset('js/alpine.js') }}"></script>
    @livewireScripts
</body>
</html>
