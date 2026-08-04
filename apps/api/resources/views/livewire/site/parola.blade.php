{{--
    Parola sıfırlama — tasarım 12-sw-giris.jsx · SifreSayfa.

    Tasarım "Bağlantı 30 dakika geçerli" diyor; gerçek süre config/auth.php `passwords.users.expire`
    değeridir (bugün 60). Talimat gereği config'e DOKUNULMADI, metin gerçeğe uyduruldu — yoksa site
    sunucuyla yalan söylerdi.
--}}
@if ($asama === 1)
    <x-site.kimlik-kabuk kulak="Parola" baslik="Bağlantıyı gönderdik."
        aciklama="{{ $gonderilen }} adresine parola yenileme bağlantısı gitti. Bağlantı {{ $this->gecerlilikDakika() }} dakika geçerli.">

        <x-site.kutu tur="mor" ikon="posta">
            E-posta gelmediyse gereksiz (spam) klasörüne bakın. Hâlâ yoksa 0850 000 00 00 numaradan bize ulaşın.
        </x-site.kutu>

        <div class="dg-grup" style="margin-top:24px">
            <button type="button" class="dg dg-c" wire:click="adresiDegistir">Adresi değiştir</button>
            <a class="dg dg-a" href="{{ route('subscription.login') }}">Girişe dön</a>
        </div>
    </x-site.kimlik-kabuk>
@else
    <x-site.kimlik-kabuk kulak="Parola" baslik="Parolanızı sıfırlayalım."
        aciklama="Hesabınızın e-posta adresini yazın; yenileme bağlantısını gönderelim.">

        <form wire:submit="gonder" novalidate>
            <x-site.alan etiket="E-posta" :hata="$errors->first('eposta')" id="s-eposta">
                <input id="s-eposta" class="gir @error('eposta') yanlis @enderror" type="email" inputmode="email"
                    autocomplete="email" placeholder="mehmet@merkezsubayi.com" wire:model="eposta">
            </x-site.alan>

            <button class="dg dg-a tam" type="submit" wire:loading.attr="disabled">
                <span wire:loading.remove wire:target="gonder">Bağlantı gönder</span>
                <span class="donen" wire:loading wire:target="gonder"></span>
            </button>
        </form>

        <a class="dg dg-d tam" style="margin-top:12px" href="{{ route('subscription.login') }}">
            <x-site.ikon ad="okSol" boy="17" kalin="2.2" />Girişe dön
        </a>
    </x-site.kimlik-kabuk>
@endif
