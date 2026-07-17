<div>
    @php($tenant = $detail['tenant'])
    <p><a href="{{ route('panel.tenants') }}">&larr; Bayiler</a></p>
    <h1>{{ $tenant->name }}</h1>

    <div class="card">
        <p><strong>Durum:</strong> <span class="status">{{ $tenant->status->value }}</span></p>
        <p><strong>Deneme bitişi:</strong> {{ $tenant->trial_ends_at?->format('Y-m-d') ?? '—' }}</p>
        <p><strong>Geçerlilik (valid_until):</strong> {{ $tenant->valid_until?->format('Y-m-d H:i') ?? '—' }}</p>
        <p><strong>Kilit anı:</strong> {{ $tenant->locked_at?->format('Y-m-d H:i') ?? '—' }}</p>
        <p><strong>Kullanıcı / Cihaz:</strong> {{ $detail['user_count'] }} / {{ $detail['device_count'] }}</p>
    </div>

    <div class="card" style="margin-top:1rem;">
        <h2>Abonelik & Durum</h2>
        <p>
            <label>Deneme uzat (gün):
                <input type="number" wire:model="extendDays" min="1" style="width:70px">
            </label>
            <button wire:click="extendTrial">Denemeyi Uzat</button>
        </p>
        <button wire:click="activate">Aboneliği Kaydet (1 yıl)</button>
        <button wire:click="lock">Kilitle</button>
        <button wire:click="unlock">Aç</button>
        <button wire:click="suspend">Askıya Al</button>
    </div>

    <div class="card" style="margin-top:1rem;">
        <h2>Modüller & Hesap</h2>
        <p>
            <strong>Boş/emanet takibi:</strong>
            {{ ($tenant->modules['empty_tracking'] ?? false) ? 'AÇIK' : 'kapalı' }}
            <button wire:click="toggleModule('empty_tracking')">Değiştir</button>
        </p>
        <p>
            <button wire:click="resetPassword">Patron Şifresini Sıfırla</button>
            @if ($newPassword)
                <span class="status">Yeni parola: <code>{{ $newPassword }}</code> (bir kez gösterilir)</span>
            @endif
        </p>
        <p><a href="{{ route('panel.tenant.export', $tenant->id) }}">Veriyi Dışa Aktar (JSON)</a></p>
    </div>

    <div class="card" style="margin-top:1rem;">
        <h2>Kullanım (churn sinyalleri)</h2>
        <p><strong>Aktif cihaz (7 gün):</strong> {{ $activeDevices }}</p>
        <p><strong>Kurulumdan ilk siparişe:</strong>
            {{ $minutesToFirstOrder !== null ? $minutesToFirstOrder.' dk' : 'henüz sipariş yok' }}</p>
        <p><strong>Günlük sipariş (7 gün):</strong>
            @forelse ($dailyOrders as $date => $count) {{ $date }}: {{ $count }} · @empty yok @endforelse</p>
        <p><strong>Sipariş girme saatleri (30 gün):</strong>
            @foreach ($hourDistribution as $hour => $count) @if ($count > 0) {{ $hour }}h:{{ $count }} @endif @endforeach</p>
    </div>

    <div class="card" style="margin-top:1rem;">
        <h2>Cihazlar</h2>
        <table>
            <thead><tr><th>Model</th><th>Platform</th><th>Son görülme</th></tr></thead>
            <tbody>
                @forelse ($devices as $device)
                    <tr><td>{{ $device->model ?? '—' }}</td><td>{{ $device->platform ?? '—' }}</td><td>{{ $device->last_seen_at ?? '—' }}</td></tr>
                @empty
                    <tr><td colspan="3">Cihaz yok.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
</div>
