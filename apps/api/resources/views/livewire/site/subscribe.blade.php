<div>
    <h1>Abonelik</h1>
    @if (session('status'))
        <div class="card" style="background:#eefbea; margin-bottom:1rem;">{{ session('status') }}</div>
    @endif
    <div class="card" style="max-width: 520px;">
        <p><strong>Yıllık abonelik:</strong> {{ number_format($priceKurus / 100, 2, ',', '.') }} {{ $currency }}</p>
        <form wire:submit="pay">
            <p><label><input type="checkbox" wire:model="distanceSales"> Mesafeli satış sözleşmesini okudum, kabul ediyorum. <em>(placeholder)</em></label></p>
            <p><label><input type="checkbox" wire:model="preinfo"> Ön bilgilendirme formunu okudum. <em>(placeholder)</em></label></p>
            <p><label><input type="checkbox" wire:model="kvkk"> KVKK aydınlatma + açık rıza metnini kabul ediyorum. <em>(placeholder)</em></label></p>
            @error('consents') <p class="err">{{ $message }}</p> @enderror
            <button type="submit">Abone Ol</button>
        </form>
    </div>
</div>
