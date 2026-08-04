{{--
    Sekmeler — sekme çubuğu. liste: [{k, ad, ik?}, ...].
    `model`: bu sekmeyi süren Alpine değişkeninin ADI (bir üst x-data içinde tanımlı olmalı), örn:
    <div x-data="{ sekme: 'cagri' }"><x-site.sekmeler :liste="$liste" model="sekme" /> ... </div>
--}}
@props(['liste', 'model', 'tam' => false])
<div @class(['sekme-bar', 'tam' => $tam]) role="tablist">
    @foreach($liste as $x)
        <button type="button" role="tab" class="sekme"
            :aria-selected="{{ $model }} === '{{ $x['k'] }}'"
            :class="{ on: {{ $model }} === '{{ $x['k'] }}' }"
            @click="{{ $model }} = '{{ $x['k'] }}'">
            @if(!empty($x['ik']))<x-site.ikon :ad="$x['ik']" boy="17" kalin="2" />@endif
            {{ $x['ad'] }}
        </button>
    @endforeach
</div>
