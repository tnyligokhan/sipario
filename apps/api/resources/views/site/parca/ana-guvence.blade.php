{{-- Ana sayfa · Güvenceler (09-sw-ana.jsx · GuvenceBlm). Koyu bölüm. --}}
<section class="blm gece guvence-blm">
    <div class="kap">
        <x-site.blm-bas kulak="Güvence" baslik="İşin durursa defter de durur. O yüzden durmuyor." />
        <div class="guvence-grid">
            @foreach ($sw['guvence'] as $g)
                <div class="guvence">
                    <span class="guvence-ik"><x-site.ikon :ad="$g['ik']" boy="22" kalin="1.9" renk="#B3A6FF" /></span>
                    <h3 class="h3">{{ $g['t'] }}</h3>
                    <p class="gvd">{{ $g['a'] }}</p>
                </div>
            @endforeach
        </div>
    </div>
</section>
