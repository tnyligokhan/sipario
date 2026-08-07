{{--
    "Masraf Ekle" (tasarım `10-MasrafEkleModal.jsx` · MasrafEkleModal).
    Kategori SERBEST METİN DEĞİL: liste MasrafServisi::KATEGORILER'den gelir.
--}}
<x-panel.modal baslik="Masraf Ekle" wire:click="masrafModalKapat">
    @include('livewire.panel.para._hata', ['bildirim' => $bildirim])

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <x-panel.alan label="Tarih">
            <input class="girdi tab" type="date" wire:model="form.tarih">
            @error('form.tarih')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
        <x-panel.alan label="Tutar (₺)">
            <input class="girdi tab" type="text" inputmode="decimal" wire:model="form.tutar" autofocus>
            @error('form.tutar')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
    </div>

    <x-panel.alan label="Kategori">
        <select class="girdi" wire:model="form.kategori">
            @foreach ($kategoriler as $k)
                <option value="{{ $k }}">{{ $k }}</option>
            @endforeach
        </select>
        @error('form.kategori')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <x-panel.alan label="Not (isteğe bağlı)">
        <input class="girdi" wire:model="form.not" placeholder="örn. Hetzner aylık">
        @error('form.not')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <x-slot:alt>
        <button type="button" class="btn" wire:click="masrafModalKapat">Vazgeç</button>
        <button
            type="button"
            class="btn birincil"
            wire:click="masrafKaydet"
            wire:loading.attr="disabled"
            wire:target="masrafKaydet"
            @disabled($gonderiliyor)
        >Kaydet</button>
    </x-slot:alt>
</x-panel.modal>
