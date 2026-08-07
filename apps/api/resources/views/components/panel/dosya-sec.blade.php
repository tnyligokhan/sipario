{{--
    CSV/JSON dosya seçici. Native <input type=file> tasarım diline uymadığı için gizlenir,
    yerine .btn görünümlü bir <label> tıklanır. Sürükle-bırak yok (istenmedi).
    Livewire tarafında WithFileUploads trait'i + public $ad özelliği bekler.

    Kullanım:
    <x-panel.dosya-sec ad="csvDosyasi" kabul=".csv" yertut="CSV dosyası seçilmedi" />
    (Livewire bileşeninde: use WithFileUploads; public $csvDosyasi;)

    ad: input name + wire:model hedefi + wire:target (yükleniyor göstergesi ve @error için).
    kabul: input accept (vsy ".csv"). yertut: hiç dosya seçilmemişken gösterilecek metin.
--}}
@props(['ad', 'kabul' => '.csv', 'yertut' => 'Dosya seçilmedi'])

<div {{ $attributes->merge(['class' => 'dosya-sec']) }} x-data="{ dosyaAdi: '' }">
    <label class="btn" for="dosya-sec-{{ $ad }}">
        <x-panel.ikon ad="yukle" boy="15" />
        Dosya Seç
    </label>
    <input
        type="file"
        id="dosya-sec-{{ $ad }}"
        class="dosya-sec-girdi"
        accept="{{ $kabul }}"
        wire:model="{{ $ad }}"
        @change="dosyaAdi = $event.target.files.length ? $event.target.files[0].name : ''"
    >
    <span class="dosya-sec-ad soluk" x-text="dosyaAdi || @js($yertut)"></span>

    <span wire:loading wire:target="{{ $ad }}" class="dosya-sec-durum soluk">Yükleniyor…</span>

    @error($ad)
        <span class="dosya-sec-hata">{{ $message }}</span>
    @enderror
</div>
