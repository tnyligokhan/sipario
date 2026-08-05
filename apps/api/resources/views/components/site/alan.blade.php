{{-- Alan — form alanı: etiket üstte hep görünür, hata alanın altında.

     `not` (etiket satırının sağına yaslanan küçük not) İKİ biçimde gelebilir:
       · düz metin  → <x-site.alan not="isteğe bağlı">
       · işaretleme → <x-slot:not><a class="kimlik-link" ...>Parolamı unuttum</a></x-slot:not>
     İkisi de `not` adıyla çalışır, bileşende ek kod GEREKMEZ (ölçüldü): slot bir ComponentSlot,
     yani Htmlable — `{{ }}` Htmlable'ı kaçışlamaz, düz string'i kaçışlar. Yani işaretleme olduğu
     gibi, metin güvenle basılır; rastgele metne `{!! !!}` AÇMIYORUZ (XSS disiplini). --}}
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
