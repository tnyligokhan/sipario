{{--
    Parola yenileme — tasarımda karşılığı yok; kimlik kabuğunun diliyle yazıldı (bkz. bileşen notu).

    ⚠️ KÖK ÖĞE KOŞULLU OLAMAZ. Bu dosya da `@if ($bitti)` ile başlıyordu ve kardeşi
    `parola.blade.php` ile AYNI sessiz arızayı taşıyordu: Livewire kök özniteliklerini soldaki
    dekoratif `<aside>`e yerleştiriyor, form kökün dışında kalıyor ve `wire:submit` hiç
    bağlanmıyordu. Gerekçenin tamamı `parola.blade.php` başlığındadır.

    BU DOSYA AYRICA ÖNEMLİ: sıfırlama akışının İKİNCİ yarısıdır. Kardeşi onarılıp bu dosya
    unutulsaydı, bayi e-postayı alır, bağlantıya tıklar, yeni parolasını yazar ve "Parolayı
    değiştir" düğmesi hiçbir şey yapmazdı — arıza bir adım öteye taşınmış olurdu.
--}}
<x-site.kimlik-kabuk kulak="Parola"
    :baslik="$bitti ? 'Parolanız değişti.' : 'Yeni parolanızı belirleyin.'"
    :aciklama="$bitti
        ? 'Yeni parolanızla giriş yapabilirsiniz. Eski bağlantı artık çalışmaz.'
        : 'En az 8 karakter. Ekibinizle paylaşmayın — herkesin kendi hesabı olur.'">

    @if ($bitti)
        <a class="dg dg-a tam" href="{{ route('subscription.login') }}">Girişe dön</a>
    @else
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
    @endif
</x-site.kimlik-kabuk>
