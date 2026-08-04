{{-- Müşteri satır detayı: bakiye + iletişim + son siparişler. SALT-OKUNUR (yazma formdadır). --}}
@use('App\Livewire\Panel\Concerns\Bicim')
@php($m = $detay['musteri'])

<div class="dikey" style="padding:4px 0">
    <div class="bilgi-satirlar">
        <x-panel.bilgi-satir k="Müşteri">
            <span class="kalin">{{ $m->name }}</span>
        </x-panel.bilgi-satir>
        <x-panel.bilgi-satir k="Bakiye">
            <span class="tab"><x-kurus :value="$m->balance_kurus" /></span>
            @if ($m->balance_kurus > 0)
                <span style="color:var(--danger)"> (borçlu)</span>
            @endif
        </x-panel.bilgi-satir>
        @if ($m->note)
            <x-panel.bilgi-satir k="Not">{{ $m->note }}</x-panel.bilgi-satir>
        @endif
        <x-panel.bilgi-satir k="Telefon">
            @forelse ($detay['telefonlar'] as $t)
                <span class="tab">{{ $t->phone_e164 }}</span>@if ($t->is_primary) <span class="soluk">(birincil)</span>@endif@if (! $loop->last), @endif
            @empty
                <span class="soluk">yok</span>
            @endforelse
        </x-panel.bilgi-satir>
        <x-panel.bilgi-satir k="Adres">
            @forelse ($detay['adresler'] as $a)
                {{ $a->address_text }}@if ($a->region) — {{ $a->region }}@endif
                @if ($a->lat && $a->lng) <span class="soluk">konumlu</span>@endif
                @if (! $loop->last)<br>@endif
            @empty
                <span class="soluk">yok</span>
            @endforelse
        </x-panel.bilgi-satir>
    </div>

    <x-panel.kart baslik="Son siparişler" :adet="$detay['siparisler']->count().' kayıt'">
        @if ($detay['siparisler']->isEmpty())
            <x-panel.bos metin="Bu müşterinin siparişi yok." />
        @else
            <x-panel.tablo>
                <thead>
                    <tr><th>Sipariş</th><th>Durum</th><th class="sag">Tutar</th><th>Ödeme</th><th>Tarih</th></tr>
                </thead>
                <tbody>
                    @foreach ($detay['siparisler'] as $s)
                        <tr>
                            <td class="tab">{{ $s->code ? '#'.$s->code : '—' }}</td>
                            <td class="soluk">{{ $s->status }}</td>
                            <td class="sag kalin tab"><x-kurus :value="$s->total_kurus" /></td>
                            <td class="soluk">{{ $s->payment_type ?? '—' }}</td>
                            <td class="tab">{{ Bicim::tarihSaat($s->occurred_at) }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
    </x-panel.kart>
</div>
