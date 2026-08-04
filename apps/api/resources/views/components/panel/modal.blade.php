{{--
    Kullanım — kapatma eylemini TEK yerde tanımla, bileşen X butonu / Esc / dış tıklama
    üçünü de o eyleme bağlar (Alpine $refs ile x butonuna "tıklatır"):
    <x-panel.modal baslik="Ödeme Ekle" wire:click="odemeModalKapat">
        <x-panel.alan label="Tutar (₺)"><input class="girdi tab" wire:model="tutar" type="number"></x-panel.alan>
        <x-slot:alt>
            <button class="btn" wire:click="odemeModalKapat">Vazgeç</button>
            <button class="btn birincil" wire:click="odemeEkle">Kaydet</button>
        </x-slot:alt>
    </x-panel.modal>

    Ekranda @if($modalAcik) ... @endif ile şartlı basılır (Livewire, gerçek veriyle).
    wire:click yerine Alpine tabanlı bir kapatma da verilebilir (örn. @click="acik=false").
--}}
@props(['baslik'])

<div
    x-data
    x-on:keydown.escape.window="$refs.panelModalKapat.click()"
    x-on:mousedown="if ($event.target === $event.currentTarget) $refs.panelModalKapat.click()"
    class="modal-arka"
>
    <div class="modal" role="dialog" aria-modal="true" aria-labelledby="panel-modal-baslik">
        <div class="modal-baslik" id="panel-modal-baslik">
            {{ $baslik }}
            <button type="button" class="modal-kapat" x-ref="panelModalKapat" aria-label="Kapat" {{ $attributes }}>
                <x-panel.ikon ad="kapat" boy="17" />
            </button>
        </div>
        <div class="modal-govde">
            {{ $slot }}
        </div>
        @isset($alt)
            <div class="modal-alt">{{ $alt }}</div>
        @endisset
    </div>
</div>
