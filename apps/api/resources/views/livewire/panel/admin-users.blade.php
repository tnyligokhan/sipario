<div>
    <h1>Panel Hesapları</h1>
    <p class="hint">Bu ekran yalnız süper yöneticilere açıktır.
        Hesaplar SİLİNMEZ, pasifleştirilir — denetim günlüğündeki &ldquo;kim yaptı&rdquo; sütunu boşalmasın.</p>

    @if ($bildirim)
        <p @class(['bildirim', 'bildirim-ok' => $bildirim['tur'] === 'ok', 'bildirim-hata' => $bildirim['tur'] !== 'ok'])>
            {{ $bildirim['mesaj'] }}
        </p>
    @endif

    @if ($yeniParola)
        <p class="bildirim bildirim-ok">
            Yeni hesabın parolası: <code>{{ $yeniParola }}</code><br>
            <strong>Bir kez gösterilir ve saklanmaz</strong> — şimdi güvenli bir yere alın.
        </p>
    @endif

    <div class="card">
        <h2>Yeni hesap</h2>
        <form wire:submit="ekle" class="form">
            <p>
                <label>Ad *<br><input type="text" wire:model="ad" style="min-width:14rem"></label>
                @error('ad')<span class="err">{{ $message }}</span>@enderror
                <label>E-posta *<br><input type="text" wire:model="email" style="min-width:18rem"></label>
                @error('email')<span class="err">{{ $message }}</span>@enderror
                <label>Rol<br>
                    <select wire:model="rol">
                        @foreach ($roller as $deger => $etiket)
                            <option value="{{ $deger }}">{{ $etiket }}</option>
                        @endforeach
                    </select>
                </label>
            </p>
            <p><button type="submit">Hesap Aç</button></p>
            <p class="hint">
                <strong>Süper yönetici:</strong> abonelik, kilit, modül, patron şifresi ve hesap yönetimi.
                <strong>Destek:</strong> görüntüleme + veri girişi (müşteri/ürün, CSV aktarımı).
            </p>
        </form>
    </div>

    <div class="card" style="margin-top:1rem;">
        <h2>Hesaplar</h2>
        <table>
            <thead><tr><th>Ad</th><th>E-posta</th><th>Rol</th><th>Durum</th><th>Son giriş</th><th></th></tr></thead>
            <tbody>
                @forelse ($adminler as $admin)
                    <tr>
                        <td>{{ $admin->name }}@if ($admin->id === $benimId) <span class="status">siz</span>@endif</td>
                        <td>{{ $admin->email }}</td>
                        <td>
                            <select wire:change="rolDegistir('{{ $admin->id }}', $event.target.value)">
                                @foreach ($roller as $deger => $etiket)
                                    <option value="{{ $deger }}" @selected($admin->role === $deger)>{{ $etiket }}</option>
                                @endforeach
                            </select>
                        </td>
                        <td>
                            @if ($admin->pasifMi())
                                <span class="err">pasif</span>
                            @else
                                <span class="status">aktif</span>
                            @endif
                        </td>
                        <td>{{ $admin->last_login_at?->format('d.m.Y H:i') ?? '—' }}</td>
                        <td>
                            @if ($admin->pasifMi())
                                <button type="button" wire:click="aktiflik('{{ $admin->id }}', true)">Yeniden aç</button>
                            @else
                                <button type="button" wire:click="aktiflik('{{ $admin->id }}', false)">Pasifleştir</button>
                            @endif
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="6">Hesap yok.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
</div>
