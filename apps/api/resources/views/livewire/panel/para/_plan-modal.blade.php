{{--
    "Planı Düzenle" (tasarım `09-PlanDuzenleModal.jsx` · PlanDuzenleModal).

    TASARIMDAN SAPMA: "Yıllık ücret" alanı EKLENDİ. Sunucuda `plans.price_yearly_kurus` var ve
    site checkout'u onu okuyor; alansız bir modal yıllık fiyatı düzenlenemez bırakırdı.

    Bilgi kutusu metni BİREBİR taşındı ve DOĞRUdur: PlanDeposu::guncelle mevcut bayilerin
    kotalarına dokunmaz.
--}}
<x-panel.modal baslik="Planı Düzenle" wire:click="planModalKapat">
    @include('livewire.panel.para._hata', ['bildirim' => $bildirim])

    <x-panel.alan label="Plan adı">
        <input class="girdi" wire:model="planForm.ad">
        @error('planForm.ad')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <x-panel.alan label="Aylık ücret (₺)">
            <input class="girdi tab" type="text" inputmode="decimal" wire:model="planForm.aylik">
            @error('planForm.aylik')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
        <x-panel.alan label="Yıllık ücret (₺)">
            <input class="girdi tab" type="text" inputmode="decimal" wire:model="planForm.yillik">
            @error('planForm.yillik')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
        <x-panel.alan label="Deneme süresi (gün)">
            <input class="girdi tab" type="number" min="0" wire:model="planForm.denemeGun">
            @error('planForm.denemeGun')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
        <x-panel.alan label="Aylık oto-sıralama hakkı">
            <input class="girdi tab" type="number" min="0" wire:model="planForm.hakAy">
            @error('planForm.hakAy')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
        <x-panel.alan label="Kurye hesabı">
            <input class="girdi tab" type="number" min="0" wire:model="planForm.kurye">
            @error('planForm.kurye')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
    </div>

    <div class="modal-bilgi">
        <x-panel.ikon ad="bilgi" boy="15" />
        <span>Yeni ücret bundan sonra girilecek ödemelerde varsayılan olur; geçmiş kayıtlar değişmez.</span>
    </div>

    <x-slot:alt>
        <button type="button" class="btn" wire:click="planModalKapat">Vazgeç</button>
        <button
            type="button"
            class="btn birincil"
            wire:click="planKaydet"
            wire:loading.attr="disabled"
            wire:target="planKaydet"
            @disabled($gonderiliyor)
        >Kaydet</button>
    </x-slot:alt>
</x-panel.modal>
