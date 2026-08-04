{{--
    24 hücrelik yatay ısı şeridi — saat dağılımı için (örn. sipariş girme saatleri).
    Kullanım:
    <x-panel.grafik-isi :veri="$saatlikDagilim" ozet="En yoğun saat: 11:00 (24 sipariş)" />
    veri: 0..23 indeksli, 24 elemanlı sayı dizisi (saat → adet). Kısa/uzun/boş dizi verilirse
    24'e tamamlanır/kırpılır — çökmez, eksik saatler 0 sayılır.
    renk: dolu hücrelerin rengi (vsy var(--accent)). En yoğun saat tam doygunluk, boş saatler
    var(--surface-2) — ara değerler orantılı opaklıkla.
--}}
@props(['veri', 'renk' => 'var(--accent)', 'ozet' => null])

@php
    // collect()->all() ile normalize edilir — çağıran düz dizi de Collection de verse (Collection'ı
    // doğrudan (array) ile cast etmek iç özelliklerini döker, veriyi değil).
    $veri = array_slice(array_pad(collect($veri)->values()->all(), 24, 0), 0, 24);
    $enYuksek = max(1, max($veri));
    $enYuksekSaat = array_search(max($veri), $veri);
@endphp
<div {{ $attributes->merge(['class' => 'grafik-isi']) }}>
    <div class="grafik-isi-serit" role="img" aria-label="Saatlik dağılım — en yoğun saat {{ $enYuksekSaat }}:00, {{ $veri[$enYuksekSaat] }} kayıt">
        @foreach ($veri as $saat => $deger)
            @php
                $oran = $deger > 0 ? 0.22 + (0.78 * $deger / $enYuksek) : 0;
            @endphp
            <div
                class="grafik-isi-hucre"
                style="background:{{ $deger > 0 ? $renk : 'var(--surface-2)' }};opacity:{{ $deger > 0 ? $oran : 1 }}"
                title="{{ $saat }}:00 — {{ $deger }}"
            ></div>
        @endforeach
    </div>
    <div class="chart-axis">
        <span>00:00</span><span>12:00</span><span>23:00</span>
    </div>
    @if ($ozet)
        <div class="grafik-ozet soluk">{{ $ozet }}</div>
    @endif
</div>
