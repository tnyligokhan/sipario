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
<div
    class="combo"
    x-data="{
        acik: false,
        metin: '',
        liste: @js($liste),
        get eslesen() {
            const a = this.metin.toLocaleLowerCase('tr');
            return this.liste.filter(f => f.ad.toLocaleLowerCase('tr').includes(a));
        },
        sec(f) {
            this.metin = f.ad;
            this.acik = false;
            $wire.set('{{ $model }}', f.id);
        },
    }"
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
