{{-- Ürünler sekmesi — mevcut işlev korundu; form tasarımın modalına taşındı. --}}
<div class="dikey">
    <x-panel.kart baslik="Ürünler" ikon="kutu" :adet="$urunler->total().' kayıt'">
        <div class="aksiyonlar" style="border-top:none;border-bottom:1px solid var(--line)">
            <x-panel.ara-kutusu
                wire:model.live.debounce.400ms="urunArama"
                yertut="Ürün adı veya barkod"
            />
            <label class="soluk" style="display:flex;align-items:center;gap:6px;font-size:12.5px">
                <input type="checkbox" wire:model.live="urunSilinmisler"> silinenleri de göster
            </label>
            <button type="button" class="btn birincil" wire:click="urunFormAc">
                <x-panel.ikon ad="arti" boy="15" /> Yeni Ürün
            </button>
        </div>

        @if ($urunler->isEmpty())
            <x-panel.bos ikon="ara" metin="Ürün bulunamadı." />
        @else
            <x-panel.tablo>
                <thead>
                    <tr>
                        <th>Ad</th><th class="sag">Fiyat</th><th>Birim</th>
                        <th>Barkod</th><th>Durum</th><th class="sag">İşlem</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($urunler as $u)
                        <tr>
                            <td class="kalin">{{ $u->name }}</td>
                            <td class="sag kalin tab"><x-kurus :value="$u->unit_price_kurus" /></td>
                            <td class="soluk">{{ $u->unit }}</td>
                            <td class="tab soluk">{{ $u->barcode ?? '—' }}</td>
                            <td>
                                @if ($u->deleted_at)
                                    <span class="rozet iptal">silinmiş</span>
                                @elseif ($u->is_active)
                                    <span class="rozet aktif">aktif</span>
                                @else
                                    <span class="rozet askida">pasif</span>
                                @endif
                            </td>
                            <td class="sag" style="white-space:nowrap">
                                @unless ($u->deleted_at)
                                    <button type="button" class="link-btn" wire:click="urunFormAc('{{ $u->id }}')">Düzenle</button>
                                    @if ($u->is_active)
                                        <button type="button" class="link-btn" style="margin-left:10px"
                                                wire:click="urunAktiflik('{{ $u->id }}', false)">Pasifleştir</button>
                                    @else
                                        <button type="button" class="link-btn" style="margin-left:10px"
                                                wire:click="urunAktiflik('{{ $u->id }}', true)">Etkinleştir</button>
                                    @endif
                                @endunless
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
    </x-panel.kart>

    {{ $urunler->links('vendor.pagination.panel-basit') }}
</div>

@if ($urunFormAcik)
    <x-panel.modal
        :baslik="$urunForm->urunId ? 'Ürünü Düzenle' : 'Yeni Ürün'"
        wire:click="formlariKapat"
    >
        <x-panel.alan label="Ad *">
            <input class="girdi" type="text" wire:model="urunForm.ad">
        </x-panel.alan>
        @error('urunForm.ad')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

        <x-panel.alan label="Fiyat (₺) *">
            <input class="girdi tab" type="text" wire:model="urunForm.fiyat" placeholder="45,00">
        </x-panel.alan>
        @error('urunForm.fiyat')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

        <x-panel.alan label="Birim">
            <input class="girdi" type="text" wire:model="urunForm.birim" placeholder="adet">
        </x-panel.alan>

        <x-panel.alan label="Barkod">
            <input class="girdi tab" type="text" wire:model="urunForm.barkod">
        </x-panel.alan>
        @error('urunForm.barkod')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

        <div class="modal-bilgi">
            <x-panel.ikon ad="bilgi" boy="15" />
            <span>Ürün SİLİNMEZ (siparişlerde referanslıdır) — kullanımdan kaldırmak için
                satırdaki &ldquo;Pasifleştir&rdquo; düğmesini kullanın.</span>
        </div>

        <x-slot:alt>
            <button type="button" class="btn" wire:click="formlariKapat">Vazgeç</button>
            <button type="button" class="btn birincil" wire:click="urunKaydet">Kaydet</button>
        </x-slot:alt>
    </x-panel.modal>
@endif
