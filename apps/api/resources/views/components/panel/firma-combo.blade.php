{{--
    Firma arama/seçme kombosu (OdemeEkleModal, TanimlaModal). Liste bir kere sunucudan
    gelir (:firmalar), filtreleme yazarken tarayıcıda (Alpine) yapılır — ağ turu yok.
    Seçilen firmanın id'si wire:model'e $wire.set ile yazılır.

    Kullanım:
    <x-panel.firma-combo :firmalar="$firmalar" wire:model="firmaId" />
    firmalar: id/ad/il alanlı obje/dizi koleksiyonu (örn. Tenant::select('id','ad','il')->get()).
--}}
@props(['firmalar'])

@php
    $model = $attributes->wire('model')->value();
    $liste = collect($firmalar)->map(fn ($f) => [
        'id' => is_array($f) ? $f['id'] : $f->id,
        'ad' => is_array($f) ? $f['ad'] : $f->ad,
        'il' => is_array($f) ? ($f['il'] ?? '') : ($f->il ?? ''),
    ])->values();
@endphp
{{--
    x-data mantığı public/js/alpine.js'teki `firmaCombo` bileşenine taşındı (csp_safe sıkılaştırması,
    2026-08-04): CSP altında Alpine'ın öznitelik değerlendiricisi obje içi kısaltılmış metot/getter
    tanımını (`sec(f) {...}`, `get eslesen() {...}`) çözemiyor. `model` parametre olarak geçiyor
    çünkü bu bileşen iki farklı wire:model hedefiyle kullanılıyor (form.firmaId / tanimlaForm.firmaId).
--}}
<div
    class="combo"
    x-data="firmaCombo(@js($liste), @js($model))"
>
    <input
        type="text"
        class="girdi"
        x-model="metin"
        @focus="acik = true"
        @click.outside="acik = false"
        placeholder="Firma ara…"
        autocomplete="off"
    >
    <div class="combo-liste" x-show="acik && metin.length > 0 && eslesen.length > 0" x-cloak>
        <template x-for="f in eslesen" :key="f.id">
            <div class="combo-secenek" @mousedown.prevent="sec(f)">
                <span x-text="f.ad" style="font-weight:600"></span>
                <span class="soluk" x-text="f.il"></span>
            </div>
        </template>
    </div>
</div>
