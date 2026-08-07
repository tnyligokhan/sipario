{{--
    Trend çizgisi (aylık gelir/net gibi). Eksi değer alabilir: sıfır çizgisi her zaman
    çizilir, sıfırın altındaki segmentler ve noktalar var(--danger) renginde.
    Kullanım:
    <x-panel.grafik-cizgi
        :veri="[['etiket' => 'Haz', 'deger' => 4200], ['etiket' => 'Tem', 'deger' => -850]]"
        birim="₺"
        ozet="En düşük: −850 ₺ · Temmuz 2026"
    />
    veri: [['etiket' => string, 'deger' => number], ...] — sayılar negatif olabilir.
    Tek elemanlı veri tek nokta olarak ortalanır çizilir; boş dizi <x-panel.bos> gösterir, çökmez.
--}}
@props(['veri', 'yukseklik' => 120, 'renk' => 'var(--accent)', 'birim' => null, 'ozet' => null])

@php
    $veri = collect($veri)->values();
    $bos = $veri->isEmpty();

    if (! $bos) {
        $degerler = $veri->pluck('deger')->map(fn ($d) => (float) $d);
        $min = min(0, $degerler->min());
        $max = max(0, $degerler->max());
        if ($min === $max) {
            $min -= 1;
            $max += 1;
        }
        $aralik = $max - $min;
        $yOf = fn ($v) => 34 - (($v - $min) / $aralik) * 32;
        $sifirY = $yOf(0);
        $n = $veri->count();
        $genislikEtiket = 100 / $n;
        $xOf = fn ($i) => $n > 1 ? $i * (100 / ($n - 1)) : 50;
    }

    $baslikMetni = $bos
        ? 'Veri yok'
        : 'Çizgi grafik: '.$veri->map(fn ($v) => $v['etiket'].' '.$v['deger'].($birim ? ' '.$birim : ''))->join(', ');
@endphp
<div {{ $attributes->merge(['class' => 'grafik-cizgi']) }}>
    @if ($bos)
        <x-panel.bos ikon="grafik" metin="Henüz veri yok." />
    @else
        <svg viewBox="0 0 100 40" preserveAspectRatio="none" class="chart" role="img" style="height:{{ $yukseklik }}px" aria-label="{{ $baslikMetni }}">
            <title>{{ $baslikMetni }}</title>
            <line x1="0" y1="{{ $sifirY }}" x2="100" y2="{{ $sifirY }}" stroke-width="0.4" stroke-dasharray="1.5,1.5" style="stroke:var(--line-2)" />
            @for ($i = 0; $i < $veri->count() - 1; $i++)
                @php
                    $a = (float) $veri[$i]['deger'];
                    $b = (float) $veri[$i + 1]['deger'];
                    $segmentRenk = ($a < 0 || $b < 0) ? 'var(--danger)' : $renk;
                @endphp
                <line
                    x1="{{ $xOf($i) }}" y1="{{ $yOf($a) }}"
                    x2="{{ $xOf($i + 1) }}" y2="{{ $yOf($b) }}"
                    stroke-width="1.6" stroke-linecap="round"
                    style="stroke:{{ $segmentRenk }}"
                />
            @endfor
            @foreach ($veri as $i => $nokta)
                @php $deger = (float) $nokta['deger']; @endphp
                <circle cx="{{ $xOf($i) }}" cy="{{ $yOf($deger) }}" r="1.3" style="fill:{{ $deger < 0 ? 'var(--danger)' : $renk }}">
                    <title>{{ $nokta['etiket'] }}: {{ $nokta['deger'] }}{{ $birim ? ' '.$birim : '' }}</title>
                </circle>
            @endforeach
        </svg>
        <div class="chart-axis">
            @foreach ($veri as $nokta)
                <span style="width:{{ $genislikEtiket }}%">{{ $nokta['etiket'] }}</span>
            @endforeach
        </div>
    @endif
    @if ($ozet)
        <div class="grafik-ozet soluk">{{ $ozet }}</div>
    @endif
</div>
