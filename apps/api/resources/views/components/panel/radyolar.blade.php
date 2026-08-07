{{--
    Buton görünümlü tekli seçim (radio) grubu. wire:model'e VERİLEN ÖZELLİK ADI okunur,
    tıklamalar Livewire'ın $set büyüsüyle o özelliğe yazar — ek bir Livewire metodu gerekmez.
    Kullanım:
    <x-panel.radyolar :secenekler="['IBAN' => 'IBAN', 'Elden' => 'Elden']" :secili="$yontem" wire:model="yontem" />
    secenekler: [değer => etiket] ilişkisel dizi. Düz liste verilirse (['hak','kurye']) değer=etiket sayılır.
--}}
@props(['secenekler', 'secili' => null])

@php
    $secenekler = array_is_list($secenekler) ? array_combine($secenekler, $secenekler) : $secenekler;
    $model = $attributes->wire('model')->value();
@endphp
<div {{ $attributes->whereDoesntStartWith('wire:model')->merge(['class' => 'radyolar']) }} role="radiogroup">
    @foreach ($secenekler as $deger => $etiket)
        <button
            type="button"
            class="radyo @if ((string) $secili === (string) $deger) secili @endif"
            role="radio"
            aria-checked="{{ (string) $secili === (string) $deger ? 'true' : 'false' }}"
            wire:click="$set('{{ $model }}', '{{ $deger }}')"
        >{{ $etiket }}</button>
    @endforeach
</div>
