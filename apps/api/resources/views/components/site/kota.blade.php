{{-- Kota — kullanım / toplam çubuğu. --}}
@props(['kullanilan', 'toplam', 'renk' => 'var(--mor)', 'etiket' => null, 'alt' => null])
@php $yuzde = $toplam > 0 ? min(100, (int) round(($kullanilan / $toplam) * 100)) : 0; @endphp
<div class="kota">
    <div class="kota-ust">
        <span class="h4">{{ $etiket }}</span>
        <span class="kota-v tab">{{ $kullanilan }}<span class="kota-bol">/{{ $toplam }}</span></span>
    </div>
    <div class="kota-bar"><i style="width:{{ $yuzde }}%;background:{{ $renk }}"></i></div>
    @if($alt)<span class="kucuk">{{ $alt }}</span>@endif
</div>
