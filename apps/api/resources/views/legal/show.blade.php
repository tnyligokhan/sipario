{{--
    Hukuk belgesi görüntüleme. Route: /sozlesme/{doc}. Belge haritası config('subscription.legal_docs'),
    içerik legal/docs/<slug>.blade.php partial'inden gelir.

    ── 2026-08-19 · DOLDURULACAK SAYACI ─────────────────────────────────────────────────────
    Belgeler künyeyi `x-legal.deger` ile basıyor; değer config'te hâlâ yer tutucuysa bileşen
    ekrana `<mark class="doldur" data-doldur>` çiziyor. Bu işaretler METNİN İÇİNE dağılmış
    durumda — mesafeli satış sözleşmesinde altı ayrı yerde geçiyor. Belgeyi yayına alacak
    insanın bunları tek tek avlaması gerekirdi.

    Bu yüzden gövde `->render()` ile ÖNCE metne çevriliyor, işaretler SAYILIYOR ve sayfanın
    en üstüne "bu belgede N alan eksik" uyarısı basılıyor. Sayım gövdenin kendisinden okunur;
    ikinci bir liste tutulsaydı belgeye yeni bir `x-legal.deger` eklendiği gün bayatlardı.

    `@include` yerine `view()->render()` kullanmanın tek sebebi budur — çıktıyı saymak için
    önce bir dizgeye ihtiyaç var.

    ── SEO ──────────────────────────────────────────────────────────────────────────────────
    Bu sayfalar arama motorlarına AÇIKTIR ve açık kalmalıdır: "sipario kvkk", "sipario iptal"
    gibi aramalar gerçek ve bu sayfalar o aramanın doğru cevabı. Her belgenin kendi kanonik
    adresi, kendi meta açıklaması (config'teki `ozet`) ve BreadcrumbList yapısal verisi var.
--}}
@php
    /** @var array<string, array{title: string, version_key: string, ozet?: string}> $belgeler */
    $belgeler = config('subscription.legal_docs');
    $ozet = $belgeler[$slug]['ozet'] ?? ($title.' — Sipario abonelik hizmetinin yasal metni.');

    // Gövdeyi bir kez render et: hem sayfaya basılacak hem de eksik alanlar sayılacak.
    $govde = view('legal.docs.'.$slug)->render();
    $eksikSayisi = substr_count($govde, 'data-doldur');

    /*
     * ⚠️ YAPISAL VERİ DİZİSİ BURADA KURULUYOR, `@json`IN İÇİNDE DEĞİL — ve bu bir üslup
     * tercihi değil, zorunluluk. Blade'in `@json(...)` yönergesi argümanını bir PHP
     * ayrıştırıcısıyla değil, PARANTEZ SAYARAK keser; çok satırlı ve iç içe köşeli parantez
     * içeren bir dizi literali geçildiğinde ifadeyi YANLIŞ YERDEN böler ve derlenmiş görünüm
     * `ParseError: Unclosed '['` ile 500 verir (bu tam olarak yaşandı ve ölçüldü).
     * Değişken geçmek tek satırlık bir argümandır, ayrıştırıcı onu doğru keser.
     */
    $kirintiSemasi = [
        '@context' => 'https://schema.org',
        '@type' => 'BreadcrumbList',
        'itemListElement' => [
            ['@type' => 'ListItem', 'position' => 1, 'name' => 'Sipario', 'item' => route('site.ana')],
            ['@type' => 'ListItem', 'position' => 2, 'name' => 'Sözleşmeler ve politikalar', 'item' => route('legal.show', 'mesafeli-satis')],
            ['@type' => 'ListItem', 'position' => 3, 'name' => $title, 'item' => url()->current()],
        ],
    ];
@endphp

<x-layouts.site :baslik="$title.' · Sipario'" :aciklama="$ozet">
    @push('bas')
        <link rel="canonical" href="{{ url()->current() }}">
        <meta property="og:type" content="article">
        <meta property="og:title" content="{{ $title }} · Sipario">
        <meta property="og:description" content="{{ $ozet }}">
        <meta property="og:url" content="{{ url()->current() }}">
        <script type="application/ld+json" nonce="{{ \Illuminate\Support\Facades\Vite::cspNonce() }}">
            @json($kirintiSemasi, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
        </script>
    @endpush

    <section class="blm">
        <div class="kap">
            <div class="blm-bas">
                <span class="blm-kulak mn"><i></i>Yasal</span>
                <h1 class="h1">Sözleşmeler ve politikalar</h1>
                <p class="gvd b">Küçük yazıyı okunur puntoyla yazdık. Anlamadığınız bir madde varsa arayın, telefonda anlatalım.</p>
            </div>

            <div class="ys-ic">
                <nav class="hs-nav ys-nav" aria-label="Yasal belgeler">
                    @foreach ($belgeler as $anahtar => $belge)
                        <a href="{{ route('legal.show', $anahtar) }}"
                            @class(['hs-l', 'on' => $anahtar === $slug])
                            title="{{ $belge['ozet'] ?? $belge['title'] }}"
                            @if($anahtar === $slug) aria-current="page" @endif>
                            <x-site.ikon ad="belge" boy="18" kalin="2" />{{ $belge['title'] }}
                        </a>
                    @endforeach
                </nav>

                <div class="ys-govde">
                    @if ($eksikSayisi > 0)
                        {{--
                            Sayım YAYINA ALACAK İNSAN İÇİN. Ziyaretçi de görüyor ve bu bilinçli:
                            künyesi eksik bir sözleşmeyi "tamammış gibi" göstermek, eksikliği
                            gizlemek olurdu. Şirket kurulup config doldurulduğunda sayı kendiliğinden
                            sıfıra iner ve kutu hiç basılmaz — burada bir şey silmek gerekmez.
                        --}}
                        <x-site.kutu tur="kirmizi" ikon="uyari">
                            Bu belgede <strong>{{ $eksikSayisi }} alan</strong> henüz doldurulmadı
                            (metin içinde <mark class="doldur">DOLDURULACAK</mark> olarak işaretli).
                            Şirket künyesi kesinleştiğinde bu alanlar kendiliğinden dolar.
                        </x-site.kutu>
                    @endif

                    <x-site.pano :etiket="$title" genis-ic>
                        <x-slot:sag>
                            <span class="kucuk">Sürüm: {{ $version }}</span>
                        </x-slot:sag>
                        {!! $govde !!}
                    </x-site.pano>

                    {{--
                        Hedef ANA SAYFA, "aboneliğe dön" DEĞİL (2026-08-05). İki sebep, ikisi de ölçüldü:
                        (1) Bu belgeler kayıt ve ödeme ekranlarından `target="_blank"` ile YENİ SEKMEDE
                        açılıyor — yeni sekmede "geri dön" diye bir yer yoktur; bağlantı geri götürmez,
                        o sekmeyi ödeme akışına SOKAR. (2) Belgeler alt bilgiden de erişiliyor: çerez
                        politikasını okuyan ziyaretçiyi "dön" diyerek ödemeye yollamak yanlış
                        yönlendirmedir.
                    --}}
                    <div class="ys-alt">
                        <a class="dg dg-d" href="{{ route('site.ana') }}">← Ana sayfaya dön</a>
                        <span class="kucuk">Bir maddeyi anlamadıysanız <a href="{{ route('site.iletisim') }}">bize yazın</a>, açıklayalım.</span>
                    </div>
                </div>
            </div>
        </div>
    </section>
</x-layouts.site>
