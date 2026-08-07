{{-- Özellikler · "Bir gün" anlatısı (10-sw-ozellik.jsx · GunBlm). Koyu bölüm, zaman çizelgesi. --}}
<section class="blm gece">
    <div class="kap">
        <x-site.blm-bas kulak="Bir gün" baslik="Sıradan bir salı, Sipario ile." />
        <ol class="gun">
            @foreach ($sw['gun'] as $g)
                <li class="gun-s">
                    <span class="gun-saat mn">{{ $g['s'] }}</span>
                    <span class="gun-nokta"><i></i></span>
                    <div class="gun-ic">
                        <h3 class="h3">{{ $g['t'] }}</h3>
                        <p class="gvd">{{ $g['a'] }}</p>
                    </div>
                </li>
            @endforeach
        </ol>
    </div>
</section>
