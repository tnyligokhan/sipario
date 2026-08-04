{{--
    Müşteriler sekmesi — mevcut işlev AYNEN korundu, yalnız tasarım diline geçirildi.
    Form artık tasarımın modalıdır (`x-panel.modal`); alanlar, doğrulama ve yazma yolu değişmedi.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')
<div class="dikey">
    <x-panel.kart baslik="Müşteriler" ikon="uyeler" :adet="$musteriler->total().' kayıt'">
        <div class="aksiyonlar" style="border-top:none;border-bottom:1px solid var(--line)">
            <x-panel.ara-kutusu
                wire:model.live.debounce.400ms="musteriArama"
                yertut="Ad, kod veya telefon"
            />
            <label class="soluk" style="display:flex;align-items:center;gap:6px;font-size:12.5px">
                <input type="checkbox" wire:model.live="musteriSilinmisler"> silinenleri de göster
            </label>
            <button type="button" class="btn birincil" wire:click="musteriFormAc">
                <x-panel.ikon ad="arti" boy="15" /> Yeni Müşteri
            </button>
            <a class="btn" href="{{ route('panel.tenant.import', $tenantId) }}">
                <x-panel.ikon ad="yukle" boy="15" /> Toplu aktar (CSV)
            </a>
            <a class="btn" href="{{ route('panel.tenant.csv.musteriler', $tenantId) }}">
                <x-panel.ikon ad="indir" boy="15" /> Listeyi CSV indir
            </a>
        </div>

        @if ($musteriler->isEmpty())
            <x-panel.bos ikon="ara" metin="Müşteri bulunamadı." />
        @else
            <x-panel.tablo>
                <thead>
                    <tr>
                        <th>Kod</th><th>Ad</th><th>Telefon</th>
                        <th class="sag">Bakiye</th><th>Son sipariş</th><th class="sag">İşlem</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($musteriler as $m)
                        <tr>
                            <td class="tab soluk">{{ $m->code ?? '—' }}</td>
                            <td>
                                <div class="kalin">{{ $m->name }}</div>
                                @if ($m->blacklisted_at)
                                    <span class="rozet kilitli">kara liste</span>
                                @endif
                                @if ($m->deleted_at)
                                    <span class="rozet iptal">silinmiş</span>
                                @endif
                            </td>
                            <td class="tab">{{ $m->telefon ?? '—' }}</td>
                            <td class="sag kalin tab"><x-kurus :value="$m->balance_kurus" /></td>
                            <td class="tab">{{ Bicim::tarihKisa($m->son_siparis) }}</td>
                            <td class="sag" style="white-space:nowrap">
                                <button type="button" class="link-btn" wire:click="musteriAc('{{ $m->id }}')">
                                    {{ $acikMusteri === $m->id ? 'Kapat' : 'Detay' }}
                                </button>
                                @unless ($m->deleted_at)
                                    <button type="button" class="link-btn" style="margin-left:10px"
                                            wire:click="musteriFormAc('{{ $m->id }}')">Düzenle</button>
                                    @if ($m->blacklisted_at)
                                        <button type="button" class="link-btn" style="margin-left:10px"
                                                wire:click="musteriKaraListe('{{ $m->id }}', false)">Kara listeden çıkar</button>
                                    @else
                                        <button type="button" class="link-btn" style="margin-left:10px"
                                                wire:click="musteriKaraListe('{{ $m->id }}', true)">Kara listeye al</button>
                                    @endif
                                @endunless
                            </td>
                        </tr>

                        @if ($acikMusteri === $m->id && $musteriDetay)
                            <tr>
                                <td colspan="6" style="background:var(--bg)">
                                    @include('livewire.panel.tenant.musteri-detay', ['detay' => $musteriDetay])
                                </td>
                            </tr>
                        @endif
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
    </x-panel.kart>

    {{ $musteriler->links('vendor.pagination.panel-basit') }}
</div>

@if ($musteriFormAcik)
    <x-panel.modal
        :baslik="$musteriForm->musteriId ? 'Müşteriyi Düzenle' : 'Yeni Müşteri'"
        wire:click="formlariKapat"
    >
        <x-panel.alan label="Ad *">
            <input class="girdi" type="text" wire:model="musteriForm.ad">
        </x-panel.alan>
        @error('musteriForm.ad')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

        <x-panel.alan label="Telefon">
            <input class="girdi tab" type="text" wire:model="musteriForm.telefon" placeholder="0532 111 22 33">
        </x-panel.alan>
        @error('musteriForm.telefon')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

        <x-panel.alan label="Adres">
            <input class="girdi" type="text" wire:model="musteriForm.adres">
        </x-panel.alan>

        <x-panel.alan label="Bölge">
            <input class="girdi" type="text" wire:model="musteriForm.bolge" placeholder="Muratpaşa">
        </x-panel.alan>

        <x-panel.alan label="Not">
            <input class="girdi" type="text" wire:model="musteriForm.not">
        </x-panel.alan>

        {{-- Bakiye ve kara liste bu formda BİLEREK yok: bakiye defterden türer (elle yazılamaz),
             kara liste ayrı bir düğmedir — formda olsaydı her kaydetmede yeniden gönderilmesi
             gerekirdi ve unutulduğu an sessizce silinirdi. --}}
        <div class="modal-bilgi">
            <x-panel.ikon ad="bilgi" boy="15" />
            <span>Bakiye ve kara liste bu formda değildir: bakiye defterden türer,
                kara liste satırdaki düğmeyle yönetilir. Panelden girilen kayıt bayinin
                cihazlarına senkronla düşer.</span>
        </div>

        <x-slot:alt>
            <button type="button" class="btn" wire:click="formlariKapat">Vazgeç</button>
            <button type="button" class="btn birincil" wire:click="musteriKaydet">Kaydet</button>
        </x-slot:alt>
    </x-panel.modal>
@endif
