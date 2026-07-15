<div>
    <h1>Sipario Yönetim Paneli</h1>
    <div class="card" style="max-width: 380px;">
        <form wire:submit="authenticate">
            <p>
                <label>E-posta<br>
                    <input type="email" wire:model="email" autocomplete="username" style="width:100%">
                </label>
            </p>
            @error('email') <p class="err">{{ $message }}</p> @enderror
            <p>
                <label>Parola<br>
                    <input type="password" wire:model="password" autocomplete="current-password" style="width:100%">
                </label>
            </p>
            @error('password') <p class="err">{{ $message }}</p> @enderror
            <button type="submit">Giriş</button>
        </form>
    </div>
</div>
