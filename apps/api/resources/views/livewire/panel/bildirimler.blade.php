{{--
    HAVALE BİLDİRİMLERİ — tasarımda yoktur; bayinin siteden yaptığı "havale gönderdim" beyanlarının
    kuyruğu. Bu ekran olmadan bayi para gönderir ve kimse görmez.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

<x-panel.layout>
    <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
    <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

    <x-panel.ust
        baslik="Havale Bildirimleri"
        :alt="count($satirlar) . ' bekleyen bildirim · en eski önce'"
    />

    <x-panel.kart baslik="Bekleyenler" :adet="count($satirlar) . ' kayıt'">
        @if ($satirlar === [])
            <x-panel.bos ikon="belge" metin="Bekleyen havale bildirimi yok. Bayiler siteden bildirim gönderdikçe burada listelenir." />
        @else
            <x-panel.tablo>
                <thead>
                    <tr>
                        <th>Beyan tarihi</th>
                        <th>Firma</th>
                        <th class="sag">Beyan edilen</th>
                        <th>Yöntem</th>
                        <th>Referans</th>
                        <th>Not</th>
                        <th class="sag">İşlem</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($satirlar as $b)
                        <tr wire:key="bildirim-{{ $b['id'] }}">
                            <td class="tab" style="white-space:nowrap">{{ $b['tarih'] }}</td>
                            <td>
                                <a href="{{ route('panel.tenant', $b['tenant_id']) }}" class="link-btn" style="color:var(--ink)">{{ $b['firma'] }}</a>
                            </td>
                            <td class="sag kalin tab">{{ Bicim::tl($b['tutar_kurus']) }}</td>
                            <td>{{ $b['yontem'] }}</td>
                            <td class="tab">{{ $b['referans'] }}</td>
                            <td class="soluk">{{ $b['not'] }}</td>
                            <td class="sag" style="white-space:nowrap">
                                @if ($superadmin)
                                    <button type="button" class="link-btn" wire:click="eslestirAc('{{ $b['id'] }}')">Eşleştir</button>
                                    <button type="button" class="link-btn tehlike" style="margin-left:12px" wire:click="reddetAc('{{ $b['id'] }}')">Reddet</button>
                                @else
                                    <span class="soluk">—</span>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
    </x-panel.kart>

    @if ($acik !== null && $kip !== null)
        @include('livewire.panel.para._bildirim-modal')
    @endif
</x-panel.layout>
