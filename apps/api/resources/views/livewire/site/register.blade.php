<div>
    <h1>Sipario — Üyelik</h1>
    <div class="card" style="max-width: 460px;">
        <form wire:submit="submit">
            <p><label>Bayi adı<br><input type="text" wire:model="name" style="width:100%"></label></p>
            @error('name') <p class="err">{{ $message }}</p> @enderror
            <p><label>E-posta<br><input type="email" wire:model="email" autocomplete="username" style="width:100%"></label></p>
            @error('email') <p class="err">{{ $message }}</p> @enderror
            <p><label>Parola<br><input type="password" wire:model="password" autocomplete="new-password" style="width:100%"></label></p>
            @error('password') <p class="err">{{ $message }}</p> @enderror
            <p><label>Telefon (opsiyonel)<br><input type="text" wire:model="phone" style="width:100%"></label></p>
            <p>
                <label>
                    <input type="checkbox" wire:model="kvkk">
                    KVKK aydınlatma metnini okudum, kabul ediyorum. <em>(metin — placeholder)</em>
                </label>
            </p>
            @error('kvkk') <p class="err">{{ $message }}</p> @enderror
            <button type="submit">Ücretsiz Denemeyi Başlat (30 gün)</button>
        </form>
    </div>
</div>
