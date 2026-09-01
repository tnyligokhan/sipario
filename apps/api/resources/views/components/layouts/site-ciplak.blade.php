{{--
    site-ciplak — menüsüz layout: giriş, kayıt, parola sıfırlama, ödeme ekranları.
    Bu ekranlarda üst menü ve alt bilgi bilinçli olarak yok (KimlikKabuk / Ödeme kendi kabuğunu çizer).

    ── 2026-08-19 · ÖLÇÜM VE DİZİN YÖNERGESİ ────────────────────────────────────────────────
    Bu layout'a iki şey eklendi ve ikisi de "genel site"den FARKLI davranıyor:

    1. `noindex` — bu sayfaların hiçbiri arama sonucuna girmemeli. Giriş ekranının Google'da
       çıkması ne ziyaretçiye ne bize yarar; üstelik `/abonelik` ve `/parola/yenile/{token}`
       gibi adresler oturum/token bağlamı taşır, dizine girmeleri doğrudan zarardır.
       `follow` bırakıldı: buradan çıkan yasal belge bağlantılarının değeri korunsun.

    2. Ölçüm ETİKETİ VAR, çerez BANDI YOK. Dönüşüm hunisinin en kritik adımları burada
       (kayıt, ödeme); ölçmezsek "kaç kişi kayda başlayıp bitirmedi" sorusu cevapsız kalır.
       Ama bandı bu ekranlarda göstermek, tam form doldururken ekranın altını kapatan bir
       kutu demekti. Rıza kararı genel sitede verilir; verilmemişse `olcum.js` zaten hiçbir
       istek göndermez — yani band olmadan da rıza kapısı sağlamdır. Kararını vermemiş biri
       doğrudan /kayit adresine gelirse ölçülmez; bu, rızasız ölçmekten iyidir.
--}}
@props(['baslik' => 'Sipario'])
<!doctype html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $baslik }}</title>
    <meta name="robots" content="noindex,follow">
    <meta name="theme-color" content="#16131C" media="(prefers-color-scheme: dark)">
    <meta name="theme-color" content="#F5F2EE" media="(prefers-color-scheme: light)">
    <x-favicon />
    <link rel="stylesheet" href="{{ \App\Support\Varlik::url('css/site.css') }}">
    @stack('bas')
    @livewireStyles
</head>
<body>
    {{ $slot }}
    <x-site.bildirim />
    {{-- bkz. layouts/site.blade.php — sıra ve gerekçe aynı. --}}
    <script src="{{ \App\Support\Varlik::url('js/alpine.js') }}"></script>
    @livewireScripts
    <x-site.olcum />
</body>
</html>
