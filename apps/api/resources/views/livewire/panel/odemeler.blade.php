{{--
    ÖDEMELER (tasarım `08-OdemeEkleModal.jsx` · Odemeler).
    Başlıklar, sütun adları ve boş durum cümleleri tasarımdan BİREBİRdir.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

<x-panel.layout>
    <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
    <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

    <x-panel.ust baslik="Ödemeler" :alt="$kayitSayisi.' kayıt · toplam '.Bicim::tl($toplamKurus)">
        <x-slot:sag>
            <select class="girdi" style="width:auto" wire:model.live="ay">
                <option value="">Tüm aylar</option>
                @foreach ($aylar as $anahtar => $etiket)
                    <option value="{{ $anahtar }}">{{ $etiket }}</option>
                @endforeach
            </select>
            <x-panel.ara-kutusu wire:model.live.debounce.300ms="arama" yertut="Firma ara…" />
            @if ($superadmin)
                <button type="button" class="btn birincil" wire:click="odemeModalAc">
                    <x-panel.ikon ad="arti" boy="15" /> Ödeme Ekle
                </button>
            @endif
        </x-slot:sag>
    </x-panel.ust>

    <x-panel.kart>
        @if ($sayfa->isEmpty())
            <x-panel.bos
                ikon="odemeler"
                :metin="$hicKayitYok
                    ? 'Henüz ödeme kaydı yok. İlk ödemeyi sağ üstteki butonla ekleyebilirsin.'
                    : 'Bu filtreyle eşleşen ödeme yok.'"
            />
        @else
            <x-panel.tablo>
                <thead>
                    <tr>
                        <th>Tarih</th>
                        <th>Firma</th>
                        <th class="sag">Tutar</th>
                        <th>Yöntem</th>
                        <th>Dönem</th>
                        <th>Not</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($sayfa as $o)
                        <tr wire:key="odeme-{{ $o->id }}">
                            <td class="tab" style="white-space:nowrap">{{ Bicim::tarihKisa($o->occurred_at) }}</td>
                            <td>
                                {{-- Firma adı eager yüklü ilişkiden; N+1 yok. --}}
                                <a href="{{ route('panel.tenant', $o->tenant_id) }}" class="link-btn" style="color:var(--ink)">{{ $o->tenant?->name ?? '?' }}</a>
                            </td>
                            <td class="sag kalin tab">{{ Bicim::tl($o->amount_kurus) }}</td>
                            <td>{{ $yontemEtiket[$o->provider] ?? $o->provider }}</td>
                            <td>{{ $o->covers_period ?: '—' }}</td>
                            <td class="soluk">{{ $o->note ?: '—' }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
    </x-panel.kart>

    @if ($sayfa->hasPages())
        <div style="margin-top:12px">{{ $sayfa->links('vendor.pagination.panel-basit') }}</div>
    @endif

    @if ($modalAcik)
        @include('livewire.panel.para._odeme-modal')
    @endif
</x-panel.layout>
