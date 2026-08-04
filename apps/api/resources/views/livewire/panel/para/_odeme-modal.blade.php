{{--
    "Ödeme Ekle" modalı (tasarım `08-OdemeEkleModal.jsx`).

    TASARIMDAN İKİ SAPMA, ikisi de bilerek:
     1. "Abonelik dönemi" (Aylık/Yıllık) alanı EKLENDİ — prototip yalnız aylık biliyordu.
     2. Bilgi kutusundaki "1 ay uzatılır" metni seçilen döneme göre "1 ay"/"1 yıl" olur; sabit
        bıraksaydık yıllık ödemede ekran yalan söylerdi.
--}}
<x-panel.modal baslik="Ödeme Ekle" wire:click="odemeModalKapat">
    @include('livewire.panel.para._hata', ['bildirim' => $bildirim])

    <x-panel.alan label="Firma">
        <x-panel.firma-combo :firmalar="$firmalar" wire:model="form.firmaId" />
        @error('form.firmaId')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <x-panel.alan label="Tutar (₺)">
            {{-- type=number DEĞİL: esnaf "1.250,50" yazar ve number alanı virgülü yutar. --}}
            <input class="girdi tab" type="text" inputmode="decimal" wire:model="form.tutar">
            @error('form.tutar')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
        <x-panel.alan label="Tarih">
            <input class="girdi tab" type="date" wire:model="form.tarih">
            @error('form.tarih')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
    </div>

    <x-panel.alan label="Yöntem">
        <x-panel.radyolar :secenekler="['iban' => 'IBAN', 'elden' => 'Elden']" :secili="$form->yontem" wire:model="form.yontem" />
    </x-panel.alan>

    <x-panel.alan label="Abonelik dönemi">
        <x-panel.radyolar :secenekler="['monthly' => 'Aylık', 'yearly' => 'Yıllık']" :secili="$form->donem" wire:model="form.donem" />
    </x-panel.alan>

    <x-panel.alan label="Kapsadığı dönem">
        <select class="girdi" wire:model="form.kapsam">
            @foreach ($donemler as $anahtar => $etiket)
                <option value="{{ $anahtar }}">{{ $etiket }}</option>
            @endforeach
        </select>
        @error('form.kapsam')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <x-panel.alan label="Not (isteğe bağlı)">
        <input class="girdi" wire:model="form.not" placeholder="örn. Ofiste elden alındı">
        @error('form.not')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <div class="modal-bilgi">
        <x-panel.ikon ad="bilgi" boy="15" />
        <span>Kaydedildiğinde firmanın abonelik bitişi {{ $form->donem === 'yearly' ? '1 yıl' : '1 ay' }} uzatılır.</span>
    </div>

    <x-slot:alt>
        <button type="button" class="btn" wire:click="odemeModalKapat">Vazgeç</button>
        {{--
            Çift tıklama kalkanı (görsel katman): gönderim boyunca pasif. Asıl kalkan sunucudaki
            kararlı `provider_ref`tir — bkz. App\Livewire\Panel\Odemeler sınıf başlığı.
        --}}
        <button
            type="button"
            class="btn birincil"
            wire:click="odemeKaydet"
            wire:loading.attr="disabled"
            wire:target="odemeKaydet"
            @disabled($gonderiliyor)
        >Kaydet</button>
    </x-slot:alt>
</x-panel.modal>
