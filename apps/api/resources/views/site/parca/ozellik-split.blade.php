{{--
    Özellikler · beş bölüm, dönüşümlü yerleşim (10-sw-ozellik.jsx · OzellikSplit).
    Tek numaralı bölümler `kagit2` zeminli ve `ters` (maket solda) — kaynaktaki i % 2 kuralı.
--}}
@foreach ($sw['tur'] as $i => $t)
    <section @class(['blm', 'kagit2' => $i % 2])>
        <div @class(['kap', 'oz-split', 'ters' => $i % 2])>
            <div class="oz-metin">
                <span class="blm-kulak mn"><i></i>{{ $t['ad'] }}</span>
                <h2 class="h1 oz-bas">{{ $t['bas'] }}</h2>
                <p class="gvd b">{{ $t['a'] }}</p>
                <ul class="tur-liste">
                    @foreach ($t['ozet'] as $o)
                        <li>
                            <span class="tur-tik"><x-site.ikon ad="onay" boy="13" kalin="3" renk="#fff" /></span>{{ $o }}
                        </li>
                    @endforeach
                </ul>
            </div>
            <div class="oz-tel">
                <x-site.telefon :ekran="$t['ekran']" :oran="0.62" :cagri="$t['cagri']" />
            </div>
        </div>
    </section>
@endforeach
