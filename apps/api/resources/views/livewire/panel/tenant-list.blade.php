<div>
    <div style="display:flex; justify-content:space-between; align-items:center;">
        <h1>Bayiler</h1>
        <form method="POST" action="{{ route('panel.logout') }}">@csrf<button type="submit">Çıkış</button></form>
    </div>
    <table>
        <thead>
            <tr><th>Bayi</th><th>Durum</th><th>Geçerlilik</th><th></th></tr>
        </thead>
        <tbody>
            @forelse ($tenants as $tenant)
                <tr>
                    <td>{{ $tenant->name }}</td>
                    <td><span class="status">{{ $tenant->status->value }}</span></td>
                    <td>{{ $tenant->valid_until?->format('Y-m-d') ?? '—' }}</td>
                    <td><a href="{{ route('panel.tenant', $tenant->id) }}">Yönet</a></td>
                </tr>
            @empty
                <tr><td colspan="4">Bayi yok.</td></tr>
            @endforelse
        </tbody>
    </table>
</div>
