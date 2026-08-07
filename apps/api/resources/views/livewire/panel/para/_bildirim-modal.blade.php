{{--
    Havale bildirimi modalı — iki kipli: "Eşleştir" (para geldi) ve "Reddet" (gelmedi).
    Tasarımda karşılığı YOKtur; kitin diliyle yazıldı.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

<x-panel.modal :baslik="$kip === 'reddet' ? 'Bildirimi Reddet' : 'Bildirimi Eşleştir'" wire:click="kapat">
    @include('livewire.panel.para._hata', ['bildirim' => $bildirim])

    <div class="bilgi-satirlar" style="border:1px solid var(--line);border-radius:var(--r1)">
        <x-panel.bilgi-satir k="Firma">{{ $acik['firma'] }}</x-panel.bilgi-satir>
        <x-panel.bilgi-satir k="Beyan edilen tutar"><span class="tab">{{ Bicim::tl($acik['tutar_kurus']) }}</span></x-panel.bilgi-satir>
        <x-panel.bilgi-satir k="Yöntem">{{ $acik['yontem'] }}</x-panel.bilgi-satir>
        <x-panel.bilgi-satir k="Referans kodu"><span class="tab">{{ $acik['referans'] }}</span></x-panel.bilgi-satir>
        <x-panel.bilgi-satir k="Beyan tarihi"><span class="tab">{{ $acik['tarih'] }}</span></x-panel.bilgi-satir>
    </div>

    @if ($kip === 'reddet')
        <x-panel.alan label="Gerekçe">
            <textarea class="girdi" wire:model="gerekce" placeholder="örn. Ekstrede bu referansla gelen bir havale yok"></textarea>
            @error('gerekce')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>

        <div class="modal-bilgi tehlike">
            <x-panel.ikon ad="uyari" boy="15" />
            <span>Reddedilen bildirim için ödeme kaydı oluşmaz ve abonelik değişmez. Bildirim yeniden açılamaz.</span>
        </div>
    @else
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
            <x-panel.alan label="Ekstredeki tutar (₺)">
                {{-- Beyan ile ön dolar; eksik/fazla havalede GERÇEK tutar yazılır. --}}
                <input class="girdi tab" type="text" inputmode="decimal" wire:model="tutar">
                @error('tutar')<span class="alan-hata">{{ $message }}</span>@enderror
            </x-panel.alan>
            <x-panel.alan label="Kapsadığı dönem">
                <select class="girdi" wire:model="kapsam">
                    @foreach ($donemler as $anahtar => $etiket)
                        <option value="{{ $anahtar }}">{{ $etiket }}</option>
                    @endforeach
                </select>
                @error('kapsam')<span class="alan-hata">{{ $message }}</span>@enderror
            </x-panel.alan>
        </div>

        <x-panel.alan label="Abonelik dönemi">
            <x-panel.radyolar :secenekler="['monthly' => 'Aylık', 'yearly' => 'Yıllık']" :secili="$donem" wire:model="donem" />
        </x-panel.alan>

        <div class="modal-bilgi">
            <x-panel.ikon ad="bilgi" boy="15" />
            <span>Eşleştirildiğinde gerçek ödeme kaydı oluşur ve firmanın abonelik bitişi {{ $donem === 'yearly' ? '1 yıl' : '1 ay' }} uzatılır.</span>
        </div>
    @endif

    <x-slot:alt>
        <button type="button" class="btn" wire:click="kapat">Vazgeç</button>
        @if ($kip === 'reddet')
            <button
                type="button"
                class="btn tehlike"
                wire:click="reddet"
                wire:loading.attr="disabled"
                wire:target="reddet"
                @disabled($gonderiliyor)
            >Reddet</button>
        @else
            <button
                type="button"
                class="btn birincil"
                wire:click="eslestir"
                wire:loading.attr="disabled"
                wire:target="eslestir"
                @disabled($gonderiliyor)
            >Eşleştir</button>
        @endif
    </x-slot:alt>
</x-panel.modal>
