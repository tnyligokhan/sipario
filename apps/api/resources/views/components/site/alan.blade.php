{{-- Alan — form alanı: etiket üstte hep görünür, hata alanın altında.

     `not` (etiket satırının sağına yaslanan küçük not) İKİ biçimde gelebilir:
       · düz metin  → <x-site.alan not="isteğe bağlı">
       · işaretleme → <x-slot:not><a class="kimlik-link" ...>Parolamı unuttum</a></x-slot:not>
     Slot bir ComponentSlot'tur, yani Htmlable — {{ }} onu KAÇIŞLAMAZ. String olarak geldiğinde
     kaçışlanmaya devam eder; rastgele metne {!! !!} AÇMIYORUZ (XSS disiplini). --}}
@props(['etiket' => null, 'ipucu' => null, 'hata' => null, 'id' => null])
@php
    /* `not` @props'ta TANIMLI OLMAMALI: bir isim aynı anda hem prop hem adlandırılmış slot olamaz,
       props tanımı slotu gölgeler. Ölçüldü — `not` props'tayken <x-slot:not> içeriği etiketin
       DIŞINA düşüyor ve `@endslot` ham metin olarak basılıyordu. Slot yoksa attribute'a düşülür. */
    $not = $not ?? $attributes->get('not');
@endphp
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
