<div class="card">
    <h2>Denetim</h2>
    <p class="hint">Bu bayide yapılan panel eylemleri. Kayıtlar yalnız eylem türü ve hedef kimlik
        taşır — müşteri/para DEĞERİ denetim günlüğüne yazılmaz (KVKK).</p>

    <table>
        <thead><tr><th>Tarih</th><th>Admin</th><th>Eylem</th><th>Ayrıntı</th></tr></thead>
        <tbody>
            @forelse ($denetim as $k)
                <tr>
                    <td>{{ \Illuminate\Support\Carbon::parse($k->created_at)->format('d.m.Y H:i') }}</td>
                    <td>{{ $k->admin ?? '—' }}</td>
                    <td><span class="status">{{ $k->action }}</span></td>
                    <td>{{ $k->detail ?? '—' }}</td>
                </tr>
            @empty
                <tr><td colspan="4">Bu bayide panel eylemi kaydı yok.</td></tr>
            @endforelse
        </tbody>
    </table>

    @include('livewire.panel.tenant.sayfalama', ['sayfalayici' => $denetim, 'ad' => 'ksayfa'])
</div>
