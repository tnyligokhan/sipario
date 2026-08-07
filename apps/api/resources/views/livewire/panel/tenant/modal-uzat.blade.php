{{--
    Denemeyi Uzat (tasarım `07-Uyeler.jsx` · DenemeUzatModal) — hızlı seçim (+7/+15/+30) ya da özel
    tarih, altında önizleme. Önizlemeyi bileşen hesaplar (`uzatOnizleme()`) ve KAYDIN kullandığı
    tabanla aynıdır: ekranda başka, kayıtta başka bir tarih çıkarsa modal yalan söylemiş olur.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

@php($tenant = $detail['tenant'])
@php($onizleme = $this->uzatOnizleme())

<x-panel.modal :baslik="'Denemeyi Uzat — '.$tenant->name" wire:click="uzatKapat">
    <x-panel.alan label="Hızlı seçim">
        <div class="hizli-gunler">
            @foreach ([7, 15, 30] as $gun)
                <button
                    type="button"
                    class="radyo @if (trim($uzatOzelTarih) === '' && $uzatGun === $gun) secili @endif"
                    style="flex:1"
                    wire:click="hizliGun({{ $gun }})"
                >+{{ $gun }} gün</button>
            @endforeach
        </div>
    </x-panel.alan>

    <x-panel.alan label="veya özel tarih">
        <input
            class="girdi"
            type="date"
            wire:model.live="uzatOzelTarih"
            min="{{ now()->toDateString() }}"
        >
    </x-panel.alan>

    <div class="uzat-onizleme">
        Yeni deneme bitişi:
        <b>{{ Bicim::tarihKisa($onizleme) }}</b>
    </div>

    <x-slot:alt>
        <button type="button" class="btn" wire:click="uzatKapat">Vazgeç</button>
        <button type="button" class="btn birincil" wire:click="uzatKaydet">Kaydet</button>
    </x-slot:alt>
</x-panel.modal>
