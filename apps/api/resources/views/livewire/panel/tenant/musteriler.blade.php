<div class="card">
    <h2>Müşteriler</h2>
    <p class="hint">Arama ada, müşteri koduna ve telefonun son hanelerine bakar.
        Panelden girilen kayıt bayinin cihazlarına senkronla düşer.</p>

    <p>
        <input type="search" wire:model.live.debounce.400ms="musteriArama"
               placeholder="Ad, kod veya telefon" style="min-width:16rem">
        <label class="hint">
            <input type="checkbox" wire:model.live="musteriSilinmisler"> silinenleri de göster
        </label>
        <button type="button" wire:click="musteriFormAc">+ Yeni Müşteri</button>
    </p>
    <p class="hint">
        <a href="{{ route('panel.tenant.import', $tenantId) }}">Toplu aktar (CSV)</a> &middot;
        <a href="{{ route('panel.tenant.csv.musteriler', $tenantId) }}">Listeyi CSV indir</a>
    </p>

    @if ($musteriFormAcik)
        <form wire:submit="musteriKaydet" class="form">
            <h3>{{ $musteriForm->musteriId ? 'Müşteriyi Düzenle' : 'Yeni Müşteri' }}</h3>
            <p>
                <label>Ad *<br><input type="text" wire:model="musteriForm.ad" style="min-width:16rem"></label>
                @error('musteriForm.ad')<span class="err">{{ $message }}</span>@enderror
            </p>
            <p>
                <label>Telefon<br><input type="text" wire:model="musteriForm.telefon" placeholder="0532 111 22 33"></label>
                @error('musteriForm.telefon')<span class="err">{{ $message }}</span>@enderror
            </p>
            <p>
                <label>Adres<br><input type="text" wire:model="musteriForm.adres" style="min-width:24rem"></label>
                <label>Bölge<br><input type="text" wire:model="musteriForm.bolge" placeholder="Muratpaşa"></label>
            </p>
            <p><label>Not<br><input type="text" wire:model="musteriForm.not" style="min-width:24rem"></label></p>
            <p>
                <button type="submit">Kaydet</button>
                <button type="button" wire:click="formlariKapat">Vazgeç</button>
            </p>
            <p class="hint">Bakiye ve kara liste bu formda değildir: bakiye defterden türer,
                kara liste satırdaki düğmeyle yönetilir.</p>
        </form>
    @endif

    <table>
        <thead>
            <tr><th>Kod</th><th>Ad</th><th>Telefon</th><th>Bakiye</th><th>Son sipariş</th><th></th></tr>
        </thead>
        <tbody>
            @forelse ($musteriler as $m)
                <tr>
                    <td>{{ $m->code ?? '—' }}</td>
                    <td>
                        {{ $m->name }}
                        @if ($m->blacklisted_at)<span class="err">kara liste</span>@endif
                        @if ($m->deleted_at)<span class="err">silinmiş</span>@endif
                    </td>
                    <td>{{ $m->telefon ?? '—' }}</td>
                    <td><x-kurus :value="$m->balance_kurus" /></td>
                    <td>
                        {{ $m->son_siparis
                            ? \Illuminate\Support\Carbon::parse($m->son_siparis)->format('d.m.Y')
                            : '—' }}
                    </td>
                    <td>
                        <button type="button" wire:click="musteriAc('{{ $m->id }}')">
                            {{ $acikMusteri === $m->id ? 'Kapat' : 'Detay' }}
                        </button>
                        @unless ($m->deleted_at)
                            <button type="button" wire:click="musteriFormAc('{{ $m->id }}')">Düzenle</button>
                            @if ($m->blacklisted_at)
                                <button type="button" wire:click="musteriKaraListe('{{ $m->id }}', false)">Kara listeden çıkar</button>
                            @else
                                <button type="button" wire:click="musteriKaraListe('{{ $m->id }}', true)">Kara listeye al</button>
                            @endif
                        @endunless
                    </td>
                </tr>

                @if ($acikMusteri === $m->id && $musteriDetay)
                    <tr>
                        <td colspan="6" style="background:#fafafa">
                            @include('livewire.panel.tenant.musteri-detay', ['detay' => $musteriDetay])
                        </td>
                    </tr>
                @endif
            @empty
                <tr><td colspan="6">Müşteri bulunamadı.</td></tr>
            @endforelse
        </tbody>
    </table>

    @include('livewire.panel.tenant.sayfalama', ['sayfalayici' => $musteriler, 'ad' => 'msayfa'])
</div>
