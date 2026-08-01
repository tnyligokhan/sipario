<div>
    <h1>Denetim Günlüğü</h1>
    <p class="hint">Tüm bayilerdeki panel eylemleri. Kayıtlar yalnız eylem türü ve hedef kimlik
        taşır; müşteri/para DEĞERİ günlüğe yazılmaz (KVKK).</p>

    <div class="card">
        <p>
            <label>Eylem:
                <select wire:model.live="eylem">
                    <option value="">hepsi</option>
                    @foreach ($eylemTurleri as $tur)
                        <option value="{{ $tur }}">{{ $tur }}</option>
                    @endforeach
                </select>
            </label>
        </p>

        <table>
            <thead><tr><th>Tarih</th><th>Admin</th><th>Bayi</th><th>Eylem</th><th>Ayrıntı</th></tr></thead>
            <tbody>
                @forelse ($kayitlar as $k)
                    <tr>
                        <td>{{ \Illuminate\Support\Carbon::parse($k->created_at)->format('d.m.Y H:i') }}</td>
                        <td>{{ $k->admin ?? '—' }}</td>
                        <td>
                            @if ($k->tenant_id)
                                <a href="{{ route('panel.tenant', $k->tenant_id) }}">{{ $k->bayi ?? $k->tenant_id }}</a>
                            @else
                                <span class="hint">(bayi üstü)</span>
                            @endif
                        </td>
                        <td><span class="status">{{ $k->action }}</span></td>
                        <td>{{ $k->detail ?? '—' }}</td>
                    </tr>
                @empty
                    <tr><td colspan="5">Kayıt yok.</td></tr>
                @endforelse
            </tbody>
        </table>

        @include('livewire.panel.tenant.sayfalama', ['sayfalayici' => $kayitlar, 'ad' => 'gsayfa'])
    </div>
</div>
