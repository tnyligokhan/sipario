{{-- Gorsel — yer tutucu görsel; gerçek fotoğraf gelene kadar kullanılır. --}}
@props(['etiket', 'oran' => '4 / 3'])
<div {{ $attributes->class(['gorsel'])->merge(['style' => "aspect-ratio:{$oran}"]) }}>
    <span class="gorsel-c mn">{{ $etiket }}</span>
</div>
