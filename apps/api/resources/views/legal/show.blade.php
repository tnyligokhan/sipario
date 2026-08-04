{{--
    Hukuk belgesi görüntüleme. Route: /sozlesme/{doc}. Belge haritası config('subscription.legal_docs'),
    içerik legal/docs/<slug>.blade.php partial'inden gelir.

    Bu dalgada YALNIZ GÖRÜNÜM yeni tasarım diline (16-sw-yasal.jsx · YasalSayfa) taşındı:
    x-layouts.app + .card yerine x-layouts.site + .ys-ic (sol sütunda belge listesi, sağda pano).
    HUKUK METİNLERİNE DOKUNULMADI — hepsi hâlâ TASLAK ve avukat onayı bekliyor.

    Kaynaktaki sekme durumu React state'iydi; burada her belge kendi URL'sine sahip (SEO + paylaşım),
    aktif belge `request()->route('doc')` ile işaretlenir.
--}}
@php
    /** @var array<string, array{title: string, version_key: string}> $belgeler */
    $belgeler = config('subscription.legal_docs');
@endphp

<x-layouts.site :baslik="$title.' · Sipario'"
    :aciklama="$title.' — Sipario abonelik hizmetinin yasal metni. Sürüm '.$version.'.'">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    <section class="blm">
        <div class="kap">
            <div class="blm-bas">
                <span class="blm-kulak mn"><i></i>Yasal</span>
                <h1 class="h1">Sözleşmeler ve politikalar</h1>
                <p class="gvd b">Küçük yazıyı okunur puntoyla yazdık. Anlamadığınız bir madde varsa arayın, açıklayalım.</p>
            </div>

            <div class="ys-ic">
                <nav class="hs-nav ys-nav" aria-label="Yasal belgeler">
                    @foreach ($belgeler as $anahtar => $belge)
                        <a href="{{ route('legal.show', $anahtar) }}"
                            @class(['hs-l', 'on' => $anahtar === $slug])
                            @if($anahtar === $slug) aria-current="page" @endif>
                            <x-site.ikon ad="belge" boy="18" kalin="2" />{{ $belge['title'] }}
                        </a>
                    @endforeach
                </nav>

                <div class="ys-govde">
                    <x-site.pano :etiket="$title" genis-ic>
                        <x-slot:sag>
                            <span class="kucuk">Sürüm: {{ $version }}</span>
                        </x-slot:sag>
                        @include('legal.docs.'.$slug)
                    </x-site.pano>

                    <p class="kucuk" style="margin-top:18px">
                        <a href="{{ route('subscription.subscribe') }}">← Aboneliğe dön</a>
                    </p>
                </div>
            </div>
        </div>
    </section>
</x-layouts.site>
