{{--
    "Ek Paket Tanımla" (tasarım `09-PlanDuzenleModal.jsx` · TanimlaModal).

    Bilgi kutusu tasarımdan birebir: kredi paketi HAKKI artırır, kurye paketi HESAP LİMİTİNİ
    artırır ve ikisi de abonelik bitişini DEĞİŞTİRMEZ (kapasite satışı, süre satışı değil).

    Bedelsizde tutar alanı pasifleşir ve 0'a düşer — ekran, servis ve `addon_grants` CHECK'i
    aynı kuralı ayrı ayrı zorlar.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

<x-panel.modal baslik="Ek Paket Tanımla" wire:click="tanimlaModalKapat">
    @include('livewire.panel.para._hata', ['bildirim' => $bildirim])

    <x-panel.alan label="Firma">
        <x-panel.firma-combo :firmalar="$firmalar" wire:model="tanimlaForm.firmaId" />
        @error('tanimlaForm.firmaId')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <x-panel.alan label="Paket">
        @if ($satistakiler->isEmpty())
            <span class="soluk" style="font-size:13px">Satışta ek paket yok; önce katalogdan bir paketi aktifleştirin.</span>
        @else
            <select class="girdi" wire:model.live="tanimlaForm.paketId">
                @foreach ($satistakiler as $p)
                    <option value="{{ $p->id }}">{{ $p->name }} — {{ Bicim::tl($p->price_kurus) }}</option>
                @endforeach
            </select>
        @endif
        @error('tanimlaForm.paketId')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <x-panel.alan label="Tahsilat">
        <x-panel.radyolar
            :secenekler="['iban' => 'IBAN', 'elden' => 'Elden', 'bedelsiz' => 'Bedelsiz']"
            :secili="$tanimlaForm->tahsil"
            wire:model="tanimlaForm.tahsil"
        />
    </x-panel.alan>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <x-panel.alan label="Tutar (₺)">
            <input
                class="girdi tab"
                type="text"
                inputmode="decimal"
                wire:model="tanimlaForm.tutar"
                @disabled($tanimlaForm->bedelsizMi())
            >
            @error('tanimlaForm.tutar')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
        <x-panel.alan label="Tarih">
            <input class="girdi tab" type="date" wire:model="tanimlaForm.tarih">
            @error('tanimlaForm.tarih')<span class="alan-hata">{{ $message }}</span>@enderror
        </x-panel.alan>
    </div>

    <x-panel.alan label="Not (isteğe bağlı)">
        <input class="girdi" wire:model="tanimlaForm.not" placeholder="örn. Üçüncü kuryesini işe aldı">
        @error('tanimlaForm.not')<span class="alan-hata">{{ $message }}</span>@enderror
    </x-panel.alan>

    <div class="modal-bilgi">
        <x-panel.ikon ad="bilgi" boy="15" />
        <span>
            @if ($seciliPaket)
                @if ($seciliPaket->type === 'credits')
                    Firmanın hesabına {{ $seciliPaket->quantity }} oto-sıralama hakkı eklenir.
                @else
                    Firma {{ $seciliPaket->quantity }} kurye hesabı daha açabilir hâle gelir.
                @endif
            @endif
            @if ($tanimlaForm->bedelsizMi())
                Bedelsiz tanımlandığı için gelir kaydı oluşmaz.
            @else
                Tutar ödemeler listesine ve aylık gelire eklenir; abonelik bitişi değişmez.
            @endif
        </span>
    </div>

    <x-slot:alt>
        <button type="button" class="btn" wire:click="tanimlaModalKapat">Vazgeç</button>
        <button
            type="button"
            class="btn birincil"
            wire:click="tanimla"
            wire:loading.attr="disabled"
            wire:target="tanimla"
            @disabled($gonderiliyor || $satistakiler->isEmpty())
        >Tanımla</button>
    </x-slot:alt>
</x-panel.modal>
