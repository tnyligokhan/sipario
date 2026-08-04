{{-- Alan — form alanı: etiket üstte hep görünür, hata alanın altında. --}}
@props(['etiket' => null, 'not' => null, 'ipucu' => null, 'hata' => null, 'id' => null])
<div class="alan">
    @if($etiket)
        <label class="etk" for="{{ $id }}">{{ $etiket }}@if($not)<small>{{ $not }}</small>@endif</label>
    @endif
    {{ $slot }}
    @if($hata)
        <span class="hata"><x-site.ikon ad="uyari" boy="14" kalin="2.3" />{{ $hata }}</span>
    @elseif($ipucu)
        <span class="yardim">{{ $ipucu }}</span>
    @endif
</div>
