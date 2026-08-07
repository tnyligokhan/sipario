{{--
    Arama kutusu (büyüteç ikonlu girdi). wire:model'i doğrudan input'a ilet.
    Kullanım: <x-panel.ara-kutusu wire:model.live="arama" yertut="Firma, yetkili veya il ara…" />
--}}
@props(['yertut' => 'Ara…'])

<div class="ara">
    <x-panel.ikon ad="ara" boy="15" />
    <input type="search" class="girdi" placeholder="{{ $yertut }}" {{ $attributes }} autocomplete="off">
</div>
