{{--
    Özellikler · beş alan, kaydırdıkça biriken levhalar.

    ── YIĞILMA NASIL ÇALIŞIYOR ──────────────────────────────────────────────────────────────
    Her levha `position:sticky` ile üstte tutunuyor ve tutunma noktası sırayla biraz daha
    aşağıda (`--i`). Sayfa kaydıkça bir sonraki levha bir öncekinin üstüne biniyor, altındakinin
    yalnız üst kenarı görünür kalıyor — beş kart sonunda üst üste birikmiş bir deste oluyor.

    ⚠️ ÜÇ ŞART, üçü de sessizce bozulabilir:
      1. Levhalar OPAK olmalı (`background:var(--yuzey)`), yoksa altındaki metin üstündekinden
         okunur ve yığın çamura döner.
      2. Hiçbir ata öge `overflow:hidden` taşımamalı — `position:sticky` o anda sessizce
         `static` gibi davranır ve efekt hiç görünmez, hata da vermez.
      3. `--i` sırası HTML'den gelir; CSS'te `:nth-child` ile yazmak beş kartla sınırlı bir
         kural olurdu, alan sayısı veriden geliyor.

    Dar ekranda yığılma KAPALI (CSS'te `position:static`): telefonda levhalar zaten ekran boyu
    ve üst üste binen kartlar okumayı bitirir.
--}}
<section class="blm kagit2">
    <div class="kap">
        <div class="oz-alanlar">
            @foreach ($sw['tur'] as $i => $t)
                <article class="oz-k" id="{{ $t['k'] }}" style="--i:{{ $i }}">
                    <div class="oz-k-kimlik">
                        <span class="oz-k-ik"><x-site.ikon :ad="$t['ik']" boy="21" kalin="1.9" renk="var(--mor)" /></span>
                        <span class="mn oz-k-no">{{ str_pad((string) ($i + 1), 2, '0', STR_PAD_LEFT) }}</span>
                        <span class="h3 oz-k-ad">{{ $t['ad'] }}</span>
                    </div>
                    <div class="oz-k-anlati">
                        <h2 class="h2">{{ $t['bas'] }}</h2>
                        <p class="gvd">{{ $t['a'] }}</p>
                        <ul class="oz-k-liste">
                            @foreach ($t['ozet'] as $o)
                                <li><x-site.ikon ad="onay" boy="15" kalin="2.8" renk="var(--yesil)" />{{ $o }}</li>
                            @endforeach
                        </ul>
                    </div>
                </article>
            @endforeach
        </div>
    </div>
</section>
