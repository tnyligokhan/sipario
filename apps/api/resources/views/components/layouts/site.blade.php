{{--
    site — sipario.com.tr genel site layout'u: üst menü + slot + alt bilgi.
    `koyu`: ana sayfadaki gibi koyu/transparan hero altında şeffaf nav (bkz. 17-sw-uygulama.jsx'teki
    `document.body.dataset.koyu = sayfa === 'ana' ? '1' : ''`). koyu=true iken <main> "ic" sınıfını
    ALMAZ (hero tam genişlikte nav'ın altına akar); koyu=false iken "ic" sınıfı üst boşluğu verir.
    `oturum`: bayi oturum durumu — üst menüye iletilir. Geçilmezse (null) layout kendisi karar
    verir; açıkça true/false geçen sayfa kararı devralır.
--}}
@props([
    'baslik' => 'Sipario — Telefon çaldığında müşteriniz ekranda',
    'aciklama' => null,
    'koyu' => false,
    'oturum' => null,
])
@php
    /*
     * OTURUM VARLIĞI OTURUMDAN OKUNUR, KULLANICI YÜKLENMEZ (2026-08-05, ölçülerek bulundu).
     *
     * `Auth::guard('web')->check()` bu sayfalarda YANLIŞ CEVAP verir ve sebebi mimaridir:
     * genel site sayfaları `Route::view(...)` ile basılır ve `tenant` middleware'i TAŞIMAZ, yani
     * `app.tenant_id` kurulmamıştır; `users` tablosunda RLS FORCE açık olduğu için kullanıcıyı
     * ID ile yüklemek SIFIR SATIR döndürür ve giriş yapmış patron "misafir" görünür.
     * Ölçüm (oturum çerezli curl, ana sayfa): authcheck=false · oturumdaki login anahtarı=VAR ·
     * current_setting('app.tenant_id')=NULL · aynı çerezle /hesap=200. Yani oturum sağlam,
     * yalnız kullanıcı OKUNAMIYOR.
     *
     * Çare `tenant` middleware'ini her genel sayfaya takmak DEĞİL: o middleware her isteği bir
     * transaction'a sarar ve pazarlama sayfalarına bedava bir DB turu bindirir; üstelik
     * RouteCoverageGuardTest her `tenant`lı route'tan izolasyon senaryosu ister — statik bir
     * pazarlama sayfası için ödenecek bedel değil.
     *
     * Bunun yerine oturumun KENDİSİNE bakılır: SessionGuard giriş anında `getName()` anahtarını
     * oturuma yazar, çıkışta siler. Sıfır sorgu, sıfır transaction, kullanıcı hiç yüklenmediği
     * için oturumu düşürme riski de yok (ölçümde de düşmedi: ana sayfadan sonra /hesap yine 200).
     *
     * Bu YALNIZCA menüde "Hesabım" mı "Giriş yap" mı gösterileceğine karar verir — yetki kapısı
     * DEĞİLDİR. Gerçek kapı `/hesap` üzerindeki `auth:web` + `tenant`tır; anahtar bayatsa en kötü
     * ihtimalle "Hesabım" giriş ekranına düşer, veri açılmaz.
     */
    $oturumAcik = $oturum ?? session()->has(Auth::guard('web')->getName());
@endphp
<!doctype html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $baslik }}</title>
    @if ($aciklama)
        <meta name="description" content="{{ $aciklama }}">
    @endif
    <link rel="stylesheet" href="{{ asset('css/site.css') }}">
    {{--
        Sayfaya özel <head> içeriği: canonical, og:/twitter kartları, yapısal veri.
        Bu bir SATIŞ sitesidir — her sayfanın kendi meta açıklaması ve kanonik adresi olmalı.
        Kullanım (sayfa görünümünde):  @push('bas') <link rel="canonical" href="..."> @endpush
        Basit meta açıklama için yığına gerek yok, `aciklama` prop'u yeterli.
    --}}
    @stack('bas')
    @livewireStyles
</head>
<body @if($koyu) data-koyu="1" @endif>
    <x-site.ust-menu :koyu="$koyu" :oturum="$oturumAcik" />
    <main @class(['ic' => !$koyu])>
        {{ $slot }}
    </main>
    <x-site.alt-bilgi :oturum="$oturumAcik" />
    <x-site.bildirim />
    {{--
        Alpine.data() kayıtları — Livewire'ın gömdüğü Alpine paketinden (asıl `@livewireScripts`)
        ÖNCE durmalı ki `alpine:init` dinleyicisi Alpine başlamadan kurulmuş olsun (bkz. dosyanın
        kendi belge başlığı: csp_safe sıkılaştırması, 2026-08-04).
    --}}
    <script src="{{ asset('js/alpine.js') }}"></script>
    @livewireScripts
</body>
</html>
