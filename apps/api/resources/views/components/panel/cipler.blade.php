{{--
    Filtre çipleri (tekli seçim). Radyolar ile aynı desen, farklı görünüm — bkz. Üyeler
    ekranındaki durum filtresi (Tümü/Deneme/Aktif/Askıda/İptal).
    Kullanım:
    <x-panel.cipler :secenekler="['tumu' => 'Tümü', 'trial' => 'Deneme', 'active' => 'Aktif']" :secili="$filtre" wire:model="filtre" />
--}}
@props(['secenekler', 'secili' => null])

@php
    $secenekler = array_is_list($secenekler) ? array_combine($secenekler, $secenekler) : $secenekler;
    $model = $attributes->wire('model')->value();
@endphp
<div {{ $attributes->whereDoesntStartWith('wire:model')->merge(['class' => 'cipler']) }} role="group">
    @foreach ($secenekler as $deger => $etiket)
        <button
            type="button"
            class="cip @if ((string) $secili === (string) $deger) secili @endif"
            aria-pressed="{{ (string) $secili === (string) $deger ? 'true' : 'false' }}"
            wire:click="$set('{{ $model }}', '{{ $deger }}')"
        >{{ $etiket }}</button>
    @endforeach
</div>
