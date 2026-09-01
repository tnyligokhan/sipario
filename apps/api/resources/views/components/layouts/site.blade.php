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
    /*
     * Arama motoru dizinine girsin mi. Varsayılan EVET — bu bir satış sitesidir. `false` geçen
     * sayfa `noindex,follow` alır (bkz. /fiyatlar): dizine girmez ama içindeki iç bağlantıların
     * değeri korunur. Sayfaların kendi `@push('bas')` bloğuna elle `<meta name="robots">`
     * yazması yerine prop olmasının sebebi, iki yerden birden basılıp çelişmesini önlemek.
     */
    'dizine' => true,
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

    {{--
        ── ARAMA MOTORU YÖNERGELERİ (2026-08-19) ────────────────────────────────────────────
        `max-image-preview:large` ve `max-snippet:-1` bilerek açık: Google'ın Türkçe sonuçlarda
        zengin parçacık göstermesini engellemek, tıklanma oranını düşürür ve karşılığında
        hiçbir şey kazandırmaz. `noarchive` YOK — önbellek kopyası bize zarar vermiyor.
    --}}
    <meta name="robots" content="{{ $dizine ? 'index,follow' : 'noindex,follow' }},max-image-preview:large,max-snippet:-1">
    <link rel="alternate" hreflang="tr-TR" href="{{ url()->current() }}">
    <link rel="alternate" hreflang="x-default" href="{{ url()->current() }}">
    <meta name="theme-color" content="#16131C" media="(prefers-color-scheme: dark)">
    <meta name="theme-color" content="#F5F2EE" media="(prefers-color-scheme: light)">
    <meta name="author" content="Sipario">
    <x-favicon />

    {{--
        ── OG / TWITTER ─────────────────────────────────────────────────────────────────────
        WhatsApp'ta paylaşılan bir bağlantının önizlemesi bu etiketlerden çıkar ve bu ürün için
        önemsiz DEĞİL: satış birebir yürüyor, bayiler siteyi birbirine WhatsApp'tan yolluyor.
        Etiketsiz bağlantı çıplak URL olarak görünür ve tıklanmaz.

        `og:image` HENÜZ YOK ve uydurulmadı: paylaşım görseli bir tasarım işidir, olmayan bir
        dosyaya işaret etmek WhatsApp'ta kırık önizleme üretir — hiç etiket olmamasından kötü.
        Görsel hazırlandığında buraya tek satır eklenecek (public/og/sipario.png, 1200×630).

        Sayfaya özel og:title/og:description gerekiyorsa `@push('bas')` ile eklenir; sonra gelen
        etiket öncekini ezmez, ama çoğu tüketici SON gördüğünü kullanır — bu yüzden yasal
        belgeler gibi özelleşmiş sayfalar kendi bloklarını basıyor.
    --}}
    <meta property="og:site_name" content="Sipario">
    <meta property="og:locale" content="tr_TR">
    <meta property="og:type" content="website">
    <meta property="og:title" content="{{ $baslik }}">
    @if ($aciklama)
        <meta property="og:description" content="{{ $aciklama }}">
    @endif
    <meta property="og:url" content="{{ url()->current() }}">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="{{ $baslik }}">
    @if ($aciklama)
        <meta name="twitter:description" content="{{ $aciklama }}">
    @endif

    <link rel="stylesheet" href="{{ \App\Support\Varlik::url('css/site.css') }}">
    {{--
        Sayfaya özel <head> içeriği: canonical, sayfaya özel og:/twitter kartları, yapısal veri.
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
    <x-site.cerez-onay />
    {{--
        ── ORGANIZATION + WEBSITE YAPISAL VERİSİ ────────────────────────────────────────────
        Her sayfada bir kez basılır; sayfaya özel şemalar (SoftwareApplication, FAQPage,
        BreadcrumbList) ilgili sayfanın kendi `@push('bas')` bloğunda.

        NEDEN `<body>` SONUNDA: yapısal veri `<head>`de de geçerlidir, ama burada `@stack`
        yarışına girmez ve sayfaların kendi şemalarıyla sıra çakışması olmaz. Google ikisini de
        okur (dokümantasyonunda açıkça yazılı).

        `telephone` ve `email` YALNIZ GERÇEKSE basılır — künye hâlâ yer tutucu ve
        "[Telefon]" yazan bir Organization şeması, arama sonucunda görünen bir kırıklıktır.
    --}}
    @php
        $kunye = config('subscription.company');
        $gercek = fn (?string $v): bool => $v !== null && $v !== '' && ! str_starts_with($v, '[');
        $org = array_filter([
            '@type' => 'Organization',
            '@id' => url('/').'#kurulus',
            'name' => 'Sipario',
            'legalName' => $gercek($kunye['title'] ?? null) ? $kunye['title'] : null,
            'url' => url('/'),
            'description' => 'Eve servis yapan esnaf için sipariş, veresiye defteri, kurye takibi ve arayan tanıma uygulaması.',
            'areaServed' => 'TR',
            'telephone' => $gercek($kunye['phone'] ?? null) ? $kunye['phone'] : null,
            'email' => $gercek($kunye['email'] ?? null) ? $kunye['email'] : null,
        ], fn ($v) => $v !== null);

        /*
         * ⚠️ Dizi `@json`ın İÇİNDE kurulmaz. Blade'in `@json(...)` yönergesi argümanını
         * parantez sayarak keser; çok satırlı iç içe dizi literali onu yanlış yerden böler ve
         * derlenmiş görünüm `ParseError` ile 500 verir (legal/show.blade.php'de ölçüldü).
         */
        $sitemaSemasi = [
            '@context' => 'https://schema.org',
            '@graph' => [
                $org,
                [
                    '@type' => 'WebSite',
                    '@id' => url('/').'#site',
                    'url' => url('/'),
                    'name' => 'Sipario',
                    'inLanguage' => 'tr-TR',
                    'publisher' => ['@id' => url('/').'#kurulus'],
                ],
            ],
        ];
    @endphp
    <script type="application/ld+json" nonce="{{ \Illuminate\Support\Facades\Vite::cspNonce() }}">
        @json($sitemaSemasi, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
    </script>
    {{--
        Alpine.data() kayıtları — Livewire'ın gömdüğü Alpine paketinden (asıl `@livewireScripts`)
        ÖNCE durmalı ki `alpine:init` dinleyicisi Alpine başlamadan kurulmuş olsun (bkz. dosyanın
        kendi belge başlığı: csp_safe sıkılaştırması, 2026-08-04).
    --}}
    <script src="{{ \App\Support\Varlik::url('js/alpine.js') }}"></script>
    @livewireScripts
    {{--
        Ölçüm EN SONDA ve `defer`li: sayfanın çizilmesini geciktirmez, Livewire/Alpine
        kurulumunu beklemez (ona hiç bağımlı değil). Rıza kapısı betiğin kendi içinde —
        bu satır bir istek üretmez, yalnız kapıyı kurar.
    --}}
    <x-site.olcum />
</body>
</html>
