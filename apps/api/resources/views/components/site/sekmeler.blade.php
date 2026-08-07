{{--
    Sekmeler — sekme çubuğu. liste: [{k, ad, ik?}, ...].
    `model`: bu sekmeyi süren Alpine değişkeninin ADI (bir üst x-data içinde tanımlı olmalı), örn:
    <div x-data="{ sekme: 'cagri' }"><x-site.sekmeler :liste="$liste" model="sekme" varsayilan="cagri" /> ... </div>

    `varsayilan`: sayfa AÇILIRKEN seçili görünecek sekmenin anahtarı — Alpine'ın `x-data`sındaki
    başlangıç değeriyle AYNI olmalı. Verilmezse hiçbir sekme sunucu çıktısında `on` sınıfını almaz
    ve seçili sekme ancak Alpine yüklendikten sonra işaretlenir: JavaScript yavaş gelen ya da hiç
    gelmeyen bir tarayıcıda (ve arama motoru tarayıcısında) çubuk seçimsiz görünür. Bu bir satış
    sitesi — ilk boyamada doğru görünmesi süs değil.
--}}
@props(['liste', 'model', 'varsayilan' => null, 'tam' => false])
<div @class(['sekme-bar', 'tam' => $tam]) role="tablist">
    @foreach($liste as $x)
        @php $ilkSecili = $varsayilan !== null && $varsayilan === $x['k']; @endphp
        <button type="button" role="tab" @class(['sekme', 'on' => $ilkSecili])
            aria-selected="{{ $ilkSecili ? 'true' : 'false' }}"
            :aria-selected="{{ $model }} === '{{ $x['k'] }}'"
            :class="{ on: {{ $model }} === '{{ $x['k'] }}' }"
            @click="{{ $model }} = '{{ $x['k'] }}'">
            @if(!empty($x['ik']))<x-site.ikon :ad="$x['ik']" boy="17" kalin="2" />@endif
            {{ $x['ad'] }}
        </button>
    @endforeach
</div>
