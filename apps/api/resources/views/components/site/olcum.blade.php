{{--
    site.olcum — ölçüm (analytics) kurulumu. Yalnız GENEL SİTE layout'una takılır; yönetim
    paneline ve API'ye ASLA takılmaz (iç aracın kullanımını Google'a raporlamanın hiçbir işi yok
    ve panel CSP'si zaten dış kaynağa kapalı).

    ── ÜÇ KAPI (config/analitik.php'de gerekçesiyle yazılı) ─────────────────────────────────
    Kimlik + ortam açık değilse burada HİÇBİR ŞEY basılmaz — ne betik etiketi, ne JSON kanalı,
    ne band. Rıza kapısı ise tarayıcı tarafındadır (public/js/olcum.js).

    ── VERİ NEDEN ÖZNİTELİKTE DEĞİL, JSON KANALINDA ────────────────────────────────────────
    `data-ga4="…"` de işe yarardı; ama ayar üç alanlı bir nesne ve büyüyecek (yarın bir alan
    daha eklenince öznitelik listesi dağılır). Depoda zaten yerleşik bir desen var: nesne yükü
    `<script type="application/json">` ile taşınır (bkz. public/js/alpine.js belge başlığı).
    Aynı deseni izlemek, iki farklı "veri taşıma yolu" olmasını önler.

    `@json` varsayılan bayraklarıyla (HEX_TAG dahil) kaçışladığı için `</script>` enjeksiyonu
    mümkün değil; içerik zaten config'ten geliyor, kullanıcı girdisi taşımıyor.

    ── NONCE ────────────────────────────────────────────────────────────────────────────────
    `type="application/json"` bloğu tarayıcıda ÇALIŞTIRILMAZ (veri kabıdır) ama CSP onu yine de
    `script-src` altında değerlendirir — nonce olmadan blok reddedilir ve ayar okunamaz.
    Bu tuzağa düşmemek için nonce açıkça basılıyor.

    ── GTM noscript ─────────────────────────────────────────────────────────────────────────
    Google'ın GTM parçası `<body>` başına bir `<noscript><iframe>` koyar. BURADA YOK ve bu
    bilinçli: iframe, JS kapalı ziyaretçiye RIZASI SORULMADAN yüklenirdi — rıza kapısı yalnız
    JS ile işlediği için o iframe kapının dışından geçen bir yol açardı. JS'siz ziyaretçi
    ölçülmez; ölçülmemesi, rızasız ölçülmesinden iyidir.
--}}
@php
    $ga4 = (string) config('analitik.measurement_id');
    $gtm = (string) config('analitik.gtm_id');
    $acik = (bool) config('analitik.enabled') && $ga4 !== '';

    // Dizi `@json`ın içinde kurulmaz — Blade yönergesi argümanı parantez sayarak keser ve çok
    // satırlı dizi literalini yanlış yerden böler (legal/show.blade.php'de 500'le ölçüldü).
    $ayar = ['ga4' => $ga4, 'gtm' => $gtm, 'cerez' => (string) config('analitik.riza_cerezi'), 'gun' => (int) config('analitik.riza_gun')];
@endphp

@if ($acik)
    <script type="application/json" id="olcum-ayar" nonce="{{ \Illuminate\Support\Facades\Vite::cspNonce() }}">
        @json($ayar, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
    </script>
    <script src="{{ asset('js/olcum.js') }}" defer></script>
@endif
