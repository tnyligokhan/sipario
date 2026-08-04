{{--
    Form alanı etiketi + girdi sarmalayıcı. Kullanım:
    <x-panel.alan label="Firma adı"><input class="girdi" wire:model="ad"></x-panel.alan>
--}}
@props(['label'])

<div {{ $attributes->merge(['class' => 'alan']) }}>
    <label>{{ $label }}</label>
    {{ $slot }}
</div>
