<div class="card">
    <h2>Defter</h2>
    <p class="hint">SALT-OKUNUR — defter append-only'dir; panelden para kaydı girilmez/silinmez.</p>

    <p>
        @foreach ($defterOzet as $o)
            <span class="status">{{ $o->entry_type }}: {{ $o->adet }} kayıt / <x-kurus :value="$o->toplam" /></span>
        @endforeach
        @if ($defterOzet->isEmpty())<span class="hint">Hiç defter kaydı yok.</span>@endif
    </p>

    <p>
        <label>Tip:
            <select wire:model.live="defterTip" wire:change="defterSuzgeciUygula">
                <option value="">hepsi</option>
                <option value="debit">borç (debit)</option>
                <option value="payment">tahsilat (payment)</option>
                <option value="credit">alacak (credit)</option>
                <option value="discount">iskonto (discount)</option>
                <option value="correction">düzeltme (correction)</option>
            </select>
        </label>
    </p>

    <table>
        <thead>
            <tr><th>Tarih</th><th>Müşteri</th><th>Tip</th><th>Tutar</th><th>Ödeme</th><th>Not</th></tr>
        </thead>
        <tbody>
            @forelse ($defter as $d)
                <tr>
                    <td>{{ \Illuminate\Support\Carbon::parse($d->occurred_at)->format('d.m.Y H:i') }}</td>
                    <td>{{ $d->musteri ?? '—' }}</td>
                    <td><span class="status">{{ $d->entry_type }}</span></td>
                    <td><x-kurus :value="$d->amount_kurus" /></td>
                    <td>{{ $d->payment_type ?? '—' }}</td>
                    <td>{{ $d->note ?? '—' }}</td>
                </tr>
            @empty
                <tr><td colspan="6">Defter kaydı bulunamadı.</td></tr>
            @endforelse
        </tbody>
    </table>

    @include('livewire.panel.tenant.sayfalama', ['sayfalayici' => $defter, 'ad' => 'dsayfa'])
</div>
