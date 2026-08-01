<div class="card">
    <h2>Ürünler</h2>

    <p>
        <input type="search" wire:model.live.debounce.400ms="urunArama"
               placeholder="Ürün adı veya barkod" style="min-width:16rem">
        <label class="hint">
            <input type="checkbox" wire:model.live="urunSilinmisler"> silinenleri de göster
        </label>
        <button type="button" wire:click="urunFormAc">+ Yeni Ürün</button>
    </p>

    @if ($urunFormAcik)
        <form wire:submit="urunKaydet" class="form">
            <h3>{{ $urunForm->urunId ? 'Ürünü Düzenle' : 'Yeni Ürün' }}</h3>
            <p>
                <label>Ad *<br><input type="text" wire:model="urunForm.ad" style="min-width:16rem"></label>
                @error('urunForm.ad')<span class="err">{{ $message }}</span>@enderror
            </p>
            <p>
                <label>Fiyat (₺) *<br><input type="text" wire:model="urunForm.fiyat" placeholder="45,00" style="width:8rem"></label>
                @error('urunForm.fiyat')<span class="err">{{ $message }}</span>@enderror
                <label>Birim<br><input type="text" wire:model="urunForm.birim" placeholder="adet" style="width:8rem"></label>
                <label>Barkod<br><input type="text" wire:model="urunForm.barkod" style="width:14rem"></label>
            </p>
            <p>
                <button type="submit">Kaydet</button>
                <button type="button" wire:click="formlariKapat">Vazgeç</button>
            </p>
            <p class="hint">Ürün SİLİNMEZ (siparişlerde referanslıdır) — kullanımdan kaldırmak için
                satırdaki &ldquo;Pasifleştir&rdquo; düğmesini kullanın.</p>
        </form>
    @endif

    <table>
        <thead><tr><th>Ad</th><th>Fiyat</th><th>Birim</th><th>Barkod</th><th>Durum</th><th></th></tr></thead>
        <tbody>
            @forelse ($urunler as $u)
                <tr>
                    <td>{{ $u->name }}</td>
                    <td><x-kurus :value="$u->unit_price_kurus" /></td>
                    <td>{{ $u->unit }}</td>
                    <td>{{ $u->barcode ?? '—' }}</td>
                    <td>
                        @if ($u->deleted_at)
                            <span class="err">silinmiş</span>
                        @elseif ($u->is_active)
                            <span class="status">aktif</span>
                        @else
                            <span class="status">pasif</span>
                        @endif
                    </td>
                    <td>
                        @unless ($u->deleted_at)
                            <button type="button" wire:click="urunFormAc('{{ $u->id }}')">Düzenle</button>
                            @if ($u->is_active)
                                <button type="button" wire:click="urunAktiflik('{{ $u->id }}', false)">Pasifleştir</button>
                            @else
                                <button type="button" wire:click="urunAktiflik('{{ $u->id }}', true)">Etkinleştir</button>
                            @endif
                        @endunless
                    </td>
                </tr>
            @empty
                <tr><td colspan="6">Ürün bulunamadı.</td></tr>
            @endforelse
        </tbody>
    </table>

    @include('livewire.panel.tenant.sayfalama', ['sayfalayici' => $urunler, 'ad' => 'usayfa'])
</div>
