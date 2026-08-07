{{-- Parola yenileme — tasarımda karşılığı yok; kimlik kabuğunun diliyle yazıldı (bkz. bileşen notu). --}}
@if ($bitti)
    <x-site.kimlik-kabuk kulak="Parola" baslik="Parolanız değişti."
        aciklama="Yeni parolanızla giriş yapabilirsiniz. Eski bağlantı artık çalışmaz.">
        <a class="dg dg-a tam" href="{{ route('subscription.login') }}">Girişe dön</a>
    </x-site.kimlik-kabuk>
@else
    <x-site.kimlik-kabuk kulak="Parola" baslik="Yeni parolanızı belirleyin."
        aciklama="En az 8 karakter. Ekibinizle paylaşmayın — herkesin kendi hesabı olur.">

        <form wire:submit="kaydet" novalidate>
            <x-site.alan etiket="E-posta" id="y-eposta">
                <input id="y-eposta" class="gir" type="email" value="{{ $eposta }}" readonly disabled>
            </x-site.alan>

            <x-site.alan etiket="Yeni parola" :hata="$errors->first('parola')" id="y-parola">
                <input id="y-parola" class="gir @error('parola') yanlis @enderror" type="password"
                    autocomplete="new-password" placeholder="••••••••" wire:model="parola">
            </x-site.alan>

            <x-site.alan etiket="Yeni parola (tekrar)" id="y-parola2">
                <input id="y-parola2" class="gir" type="password"
                    autocomplete="new-password" placeholder="••••••••" wire:model="parolaTekrar">
            </x-site.alan>

            <button class="dg dg-a tam" type="submit" wire:loading.attr="disabled">
                <span wire:loading.remove wire:target="kaydet">Parolayı değiştir</span>
                <span class="donen" wire:loading wire:target="kaydet"></span>
            </button>
        </form>

        <a class="dg dg-d tam" style="margin-top:12px" href="{{ route('site.parola') }}">
            <x-site.ikon ad="okSol" boy="17" kalin="2.2" />Yeniden bağlantı iste
        </a>
    </x-site.kimlik-kabuk>
@endif
