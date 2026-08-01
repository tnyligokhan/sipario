{{-- Müşteri satır detayı: bakiye + iletişim + son siparişler. SALT-OKUNUR (yazma D3 formundadır). --}}
@php($m = $detay['musteri'])

<div class="detay">
    <p>
        <strong>{{ $m->name }}</strong>
        &middot; bakiye <x-kurus :value="$m->balance_kurus" />
        @if ($m->balance_kurus > 0)<span class="err">(borçlu)</span>@endif
    </p>
    @if ($m->note)<p class="hint">Not: {{ $m->note }}</p>@endif

    <p class="hint">
        <strong>Telefon:</strong>
        @forelse ($detay['telefonlar'] as $t)
            {{ $t->phone_e164 }}@if ($t->is_primary) (birincil)@endif@if (! $loop->last), @endif
        @empty
            yok
        @endforelse
    </p>

    <p class="hint">
        <strong>Adres:</strong>
        @forelse ($detay['adresler'] as $a)
            {{ $a->address_text }}@if ($a->region) — {{ $a->region }}@endif
            @if ($a->lat && $a->lng) <span class="status">konumlu</span>@endif
            @if (! $loop->last)<br>@endif
        @empty
            yok
        @endforelse
    </p>

    <table>
        <thead><tr><th>Sipariş</th><th>Durum</th><th>Tutar</th><th>Ödeme</th><th>Tarih</th></tr></thead>
        <tbody>
            @forelse ($detay['siparisler'] as $s)
                <tr>
                    <td>{{ $s->code ? '#'.$s->code : '—' }}</td>
                    <td><span class="status">{{ $s->status }}</span></td>
                    <td><x-kurus :value="$s->total_kurus" /></td>
                    <td>{{ $s->payment_type ?? '—' }}</td>
                    <td>{{ \Illuminate\Support\Carbon::parse($s->occurred_at)->format('d.m.Y H:i') }}</td>
                </tr>
            @empty
                <tr><td colspan="5">Bu müşterinin siparişi yok.</td></tr>
            @endforelse
        </tbody>
    </table>
</div>
