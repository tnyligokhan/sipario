{{--
    Pano — mürekkep konturlu kutu, isteğe bağlı mono başlık bandı.
    Ekstra CSS sınıfı eklemek için standart `class="..."` özniteliğini kullanın (React kaynağındaki
    `sinif` prop'unun Blade karşılığı $attributes->class() ile otomatik birleşir).
--}}
@props(['etiket' => null, 'ince' => false, 'duz' => false, 'ic' => true, 'sikIc' => false, 'genisIc' => false])
<div {{ $attributes->class(['pano', 'ince' => $ince, 'duz' => $duz]) }}>
    @if($etiket)
        <div class="pano-bas">
            <span class="mn">{{ $etiket }}</span>
            @isset($sag)
                <span class="pano-bas-sag">{{ $sag }}</span>
            @endisset
        </div>
    @endif
    @if($ic)
        <div @class(['pano-ic', 'sik' => $sikIc, 'genis' => $genisIc])>{{ $slot }}</div>
    @else
        {{ $slot }}
    @endif
</div>
