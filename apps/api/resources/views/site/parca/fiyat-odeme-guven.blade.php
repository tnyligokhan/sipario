{{--
    Fiyatlandırma · ödeme güvencesi (11-sw-fiyat.jsx · OdemeGuvenBlm). Havale/EFT + elden ödeme,
    kart "yakında" — verilmiş karara BİREBİR uyuyor, dokunulmadı.
--}}
<section class="blm gece">
    <div class="kap">
        <x-site.blm-bas kulak="Ödeme" baslik="Para konusunda sürpriz olmaz." />
        <div class="guvence-grid">
            @foreach ($sw['odemeGuven'] as $x)
                <div class="guvence">
                    <span class="guvence-ik"><x-site.ikon :ad="$x['ik']" boy="22" kalin="1.9" renk="#B3A6FF" /></span>
                    <h3 class="h3">{{ $x['t'] }}</h3>
                    <p class="gvd">{{ $x['a'] }}</p>
                </div>
            @endforeach
        </div>
    </div>
</section>
