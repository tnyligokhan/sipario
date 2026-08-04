{{--
    "Ek Paket Ekle" / "Paketi Düzenle" (tasarım `09-PlanDuzenleModal.jsx` · EkPaketModal).
    Tür etiketleri ("hak" / "kurye") ve kapsam etiketinin türe göre değişmesi tasarımdan birebir.
--}}
<x-panel.modal :baslik="$paketForm->paketId ? 'Paketi Düzenle' : 'Ek Paket Ekle'" wire:click="paketModalKapat">
    @include('livewire.panel.para._hata', ['bildirim' => $bildirim])

    <x-panel.alan label="Paket türü">
        <x-panel.radyolar
            :secenekler="['credits' => 'hak', 'courier' => 'kurye']"
            :secili="$paketForm->tur"
            wire:model="paketForm.tur"
        />
    </x-panel.alan>

    <x-panel.alan label="Paket adı">
        <input
            class="girdi"
            wire:model="paketForm.ad"
            placeholder="{{ $paketForm->tur === 'credits' ? 'örn. 100 oto-sıralama hakkı' : 'örn. +1 kurye hesabı' }}"
        >
        @error('paketForm.ad')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <x-panel.alan :label="$paketForm->tur === 'credits' ? 'Hak adedi' : 'Kurye hesabı adedi'">
            <input class="girdi tab" type="number" min="1" wire:model="paketForm.adet">
            @error('paketForm.adet')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
        <x-panel.alan label="Ücret (₺)">
            <input class="girdi tab" type="text" inputmode="decimal" wire:model="paketForm.ucret">
            @error('paketForm.ucret')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
    </div>

    <x-panel.alan label="Satışta">
        <x-panel.radyolar
            :secenekler="['1' => 'Aktif', '0' => 'Pasif']"
            :secili="$paketForm->aktif"
            wire:model="paketForm.aktif"
        />
    </x-panel.alan>

    <x-slot:alt>
        <button type="button" class="btn" wire:click="paketModalKapat">Vazgeç</button>
        <button
            type="button"
            class="btn birincil"
            wire:click="paketKaydet"
            wire:loading.attr="disabled"
            wire:target="paketKaydet"
            @disabled($gonderiliyor)
        >Kaydet</button>
    </x-slot:alt>
</x-panel.modal>
