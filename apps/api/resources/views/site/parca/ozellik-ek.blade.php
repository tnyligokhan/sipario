{{-- Özellikler · ek özellikler ızgarası (10-sw-ozellik.jsx · EkBlm). --}}
<section class="blm">
    <div class="kap">
        <x-site.blm-bas kulak="Ayrıca" baslik="Küçük ama her gün lazım olanlar." />
        <div class="ek-grid">
            @foreach ($sw['ek'] as $e)
                <div class="ek">
                    <span class="ek-ik"><x-site.ikon :ad="$e['ik']" boy="20" kalin="1.9" renk="var(--mor)" /></span>
                    <h3 class="h4">{{ $e['t'] }}</h3>
                    <p class="kucuk">{{ $e['a'] }}</p>
                </div>
            @endforeach
        </div>
    </div>
</section>
