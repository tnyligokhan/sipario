{{--
    Dikey çubuk grafik. Saf SVG (JS kütüphanesi yok) — mevcut panelin yenileme takvimi
    grafiğiyle aynı desen (bkz. resources/views/livewire/panel/dashboard.blade.php).
    Kullanım:
    <x-panel.grafik-cubuk
        :veri="[['etiket' => 'Tem', 'deger' => 12], ['etiket' => 'Ağu', 'deger' => 18]]"
        birim="sipariş"
        ozet="En yüksek: 18 sipariş · Ağustos"
    />
    veri: [['etiket' => string, 'deger' => number], ...]. Boş dizi çökmez, nötr <x-panel.bos> gösterir.
    yukseklik: svg piksel yüksekliği (vsy 120). renk: çubuk rengi (vsy var(--accent)).
    birim: değerlerin yanına eklenecek birim (svg <title> için, örn. "sipariş", "₺").
    ozet: altta gösterilecek soluk özet satırı — kit hesaplamaz, çağıran verir.
--}}
@props(['veri', 'yukseklik' => 120, 'renk' => 'var(--accent)', 'birim' => null, 'ozet' => null])

@php
    $veri = collect($veri)->values();
    $bos = $veri->isEmpty();

    if (! $bos) {
        $enYuksek = max(1, (float) $veri->max('deger'));
        $genislik = 100 / $veri->count();
    }

    $baslikMetni = $bos
        ? 'Veri yok'
        : 'Çubuk grafik: '.$veri->map(fn ($v) => $v['etiket'].' '.$v['deger'].($birim ? ' '.$birim : ''))->join(', ');
@endphp
<div {{ $attributes->merge(['class' => 'grafik-cubuk']) }}>
    @if ($bos)
        <x-panel.bos ikon="grafik" metin="Henüz veri yok." />
    @else
        <svg viewBox="0 0 100 40" preserveAspectRatio="none" class="chart" role="img" style="height:{{ $yukseklik }}px" aria-label="{{ $baslikMetni }}">
            <title>{{ $baslikMetni }}</title>
            @foreach ($veri as $i => $nokta)
                @php
                    $deger = max(0, (float) $nokta['deger']);
                    $yukseklikOran = $deger / $enYuksek * 32;
                @endphp
                <rect
                    x="{{ $i * $genislik + $genislik * 0.15 }}"
                    y="{{ 34 - $yukseklikOran }}"
                    width="{{ $genislik * 0.7 }}"
                    height="{{ max($yukseklikOran, 0.4) }}"
                    style="fill:{{ $renk }}"
                ><title>{{ $nokta['etiket'] }}: {{ $nokta['deger'] }}{{ $birim ? ' '.$birim : '' }}</title></rect>
            @endforeach
        </svg>
        <div class="chart-axis">
            @foreach ($veri as $nokta)
                <span style="width:{{ $genislik }}%">{{ $nokta['etiket'] }}<br><strong class="tab">{{ $nokta['deger'] }}</strong></span>
            @endforeach
        </div>
    @endif
    @if ($ozet)
        <div class="grafik-ozet soluk">{{ $ozet }}</div>
    @endif
</div>
