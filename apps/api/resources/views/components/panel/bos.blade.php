{{--
    Boş durum. Bir kart/tablo yerine hiç kaydı olmayan bir yeri doldurmak için kullanılır.
    Kullanım: <x-panel.bos ikon="ara" metin="Aramanla eşleşen üye yok." />
    ikon verilmezse "kutu" kullanılır.
--}}
@props(['ikon' => 'kutu', 'metin'])

<div {{ $attributes->merge(['class' => 'bos']) }}>
    <div class="bos-ikon"><x-panel.ikon :ad="$ikon" boy="20" /></div>
    <div class="bos-metin">{{ $metin }}</div>
</div>
