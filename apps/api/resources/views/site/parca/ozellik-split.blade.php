{{--
    Özellikler · beş alan.

    ── DÖNÜŞÜMLÜ MAKET YERLEŞİMİ KALDIRILDI (2026-09-01, kullanıcı kararı) ──────────────────
    Eski hâli: her alan için tam yükseklikte bir bölüm, bir yanında metin, öbür yanında telefon
    maketi; tek numaralı bölümlerde taraflar yer değiştiriyor, zemin de kâğıt/kâğıt-2 arasında
    gidip geliyordu. Beş kez tekrarlanınca ortaya çıkan şey ritim değil YORGUNLUK: sayfa beş
    ekran boyu uzuyor, göz her bölümde metnin hangi tarafta olduğunu yeniden arıyor ve her
    duraklamada aynı telefon çerçevesini bir kez daha görüyordu.

    Yeni yerleşim tek sütun, sabit yön, sabit zemin — beş levha alt alta. Her levhanın solunda
    KİMLİK (sıra numarası · ikon · alanın adı), sağında ANLATI (başlık · paragraf · üç maddelik
    liste). Göz sol sütunu tarayarak sayfanın tamamını saniyeler içinde çıkarabiliyor; ayrıntı
    isteyen sağa geçiyor. Maket yok: bu sayfanın işi ekran göstermek değil, NE YAPTIĞINI anlatmak
    — ekranların yeri ana sayfanın hero'su ve mağaza sayfasıdır.

    `id` çapaları hero'daki bölüm şeridinden gelir (`$t['k']` — _veri.php'deki alan anahtarı).
    `scroll-margin-top` sabit üst menünün altına gizlenmeyi önler.
--}}
<section class="blm kagit2">
    <div class="kap oz-alanlar">
        @foreach ($sw['tur'] as $i => $t)
            <article class="oz-k" id="{{ $t['k'] }}">
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
</section>
