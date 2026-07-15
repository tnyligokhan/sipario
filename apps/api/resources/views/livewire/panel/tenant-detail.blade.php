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
</div>
