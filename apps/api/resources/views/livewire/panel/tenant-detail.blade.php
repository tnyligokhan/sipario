<div>
    @php($tenant = $detail['tenant'])
    <p><a href="{{ route('panel.tenants') }}">&larr; Bayiler</a></p>
    <h1>{{ $tenant->name }} <span class="status">{{ $tenant->status->value }}</span></h1>

    @php($sekmeler = [
        'ozet' => ['Özet', null],
        'musteriler' => ['Müşteriler', $sayilar['musteri']],
        'siparisler' => ['Siparişler', $sayilar['siparis']],
        'defter' => ['Defter', $sayilar['defter']],
        'urunler' => ['Ürünler', $sayilar['urun']],
        'denetim' => ['Denetim', $sayilar['denetim']],
    ])

    <nav class="tabs">
        @foreach ($sekmeler as $anahtar => [$etiket, $adet])
            <button type="button" wire:click="sekmeSec('{{ $anahtar }}')"
                    @class(['tab', 'on' => $sekme === $anahtar])>
                {{ $etiket }}@if ($adet !== null) <span class="tab-adet">{{ $adet }}</span>@endif
            </button>
        @endforeach
    </nav>

    @if ($bildirim)
        <p @class(['bildirim', 'bildirim-ok' => $bildirim['tur'] === 'ok', 'bildirim-hata' => $bildirim['tur'] !== 'ok'])>
            {{ $bildirim['mesaj'] }}
        </p>
    @endif

    @include('livewire.panel.tenant.'.$sekme)
</div>
