<div class="card">
    <h2>Siparişler</h2>
    <p class="hint">SALT-OKUNUR — sipariş panelden değiştirilmez (defter tutarlılığı, kırmızı çizgi #2).</p>

    <p>
        <label>Durum:
            <select wire:model.live="siparisDurum" wire:change="siparisSuzgeciUygula">
                <option value="">hepsi</option>
                <option value="open">açık</option>
                <option value="delivered">teslim</option>
                <option value="cancelled">iptal</option>
            </select>
        </label>
        <label>Başlangıç: <input type="date" wire:model.live="siparisBaslangic" wire:change="siparisSuzgeciUygula"></label>
        <label>Bitiş: <input type="date" wire:model.live="siparisBitis" wire:change="siparisSuzgeciUygula"></label>
    </p>
    {{-- CSV indirme AYNI süzgeçleri taşır: ekranda süzüp farklı bir liste indirmek en can sıkıcı
         kusurlardan biri olurdu. --}}
    <p class="hint">
        <a href="{{ route('panel.tenant.csv.siparisler', ['tenant' => $tenantId, 'durum' => $siparisDurum, 'baslangic' => $siparisBaslangic, 'bitis' => $siparisBitis]) }}">
            Bu listeyi CSV indir
        </a>
    </p>

    <table>
        <thead>
            <tr><th>Kod</th><th>Müşteri</th><th>Durum</th><th>Tutar</th><th>Ödeme</th><th>Kurye</th><th>Tarih</th></tr>
        </thead>
        <tbody>
            @forelse ($siparisler as $s)
                <tr>
                    <td>{{ $s->code ? '#'.$s->code : '—' }}</td>
                    <td>{{ $s->musteri ?? '—' }}</td>
                    <td><span class="status">{{ $s->status }}</span></td>
                    <td><x-kurus :value="$s->total_kurus" /></td>
                    <td>{{ $s->payment_type ?? '—' }}</td>
                    <td>{{ $s->kurye ?? '—' }}</td>
                    <td>{{ \Illuminate\Support\Carbon::parse($s->occurred_at)->format('d.m.Y H:i') }}</td>
                </tr>
            @empty
                <tr><td colspan="7">Bu süzgeçle sipariş bulunamadı.</td></tr>
            @endforelse
        </tbody>
    </table>

    @include('livewire.panel.tenant.sayfalama', ['sayfalayici' => $siparisler, 'ad' => 'ssayfa'])
</div>
