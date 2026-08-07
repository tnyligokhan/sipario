{{-- Ana sayfa · "Kâğıt defterin maliyeti" (09-sw-ana.jsx · DertBlm). --}}
<section class="blm kagit2">
    <div class="kap">
        <x-site.blm-bas kulak="Sorun" baslik="Kâğıt defter iyi bir defterdir. Kötü bir sistemdir."
            aciklama="Üç yerde sızdırır: alacakta, telefonda ve akşam kasada. Sipario tam bu üç yeri kapatmak için var." />
        <div class="dert-grid">
            @foreach ($sw['dert'] as $i => $d)
                <div class="dert">
                    <div class="dert-ust">
                        <span class="dert-no mn">{{ str_pad((string) ($i + 1), 2, '0', STR_PAD_LEFT) }}</span>
                        <span class="dert-ik"><x-site.ikon :ad="$d['ik']" boy="22" kalin="1.9" /></span>
                    </div>
                    <h3 class="h3">{{ $d['t'] }}</h3>
                    <p class="gvd dert-a">{{ $d['a'] }}</p>
                    <div class="dert-c">
                        <x-site.ikon ad="ok" boy="16" kalin="2.4" renk="var(--mor)" />
                        <span>{{ $d['c'] }}</span>
                    </div>
                </div>
            @endforeach
        </div>
    </div>
</section>
