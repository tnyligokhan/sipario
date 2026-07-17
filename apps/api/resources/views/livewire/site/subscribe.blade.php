<div>
    <h1>Abonelik</h1>
    @if (session('status'))
        <div class="card" style="background:#eefbea; margin-bottom:1rem;">{{ session('status') }}</div>
    @endif
    <div class="card" style="max-width: 520px;">
        <p><strong>Yıllık abonelik:</strong> {{ number_format($priceKurus / 100, 2, ',', '.') }} {{ $currency }}</p>
        <form wire:submit="pay">
            <p><label><input type="checkbox" wire:model="distanceSales"> <a href="{{ route('legal.show', 'mesafeli-satis') }}" target="_blank" rel="noopener">Mesafeli satış sözleşmesi</a>ni okudum, kabul ediyorum.</label></p>
            <p><label><input type="checkbox" wire:model="preinfo"> <a href="{{ route('legal.show', 'on-bilgilendirme') }}" target="_blank" rel="noopener">Ön bilgilendirme formu</a>nu ve <a href="{{ route('legal.show', 'iptal-iade') }}" target="_blank" rel="noopener">iptal/iade koşulları</a>nı okudum.</label></p>
            <p><label><input type="checkbox" wire:model="kvkk"> <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}" target="_blank" rel="noopener">KVKK aydınlatma + açık rıza metni</a>ni kabul ediyorum.</label></p>
            @error('consents') <p class="err">{{ $message }}</p> @enderror
            <button type="submit">Abone Ol</button>
        </form>
    </div>
</div>
