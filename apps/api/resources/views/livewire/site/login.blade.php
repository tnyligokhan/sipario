{{--
    Giriş — tasarım 12-sw-giris.jsx · GirisSayfa. Metinler birebir.

    "Bu cihazda oturumumu açık tut" kutusu TASARIMDA VAR, burada YOK: `users` tablosunda
    `remember_token` kolonu yok (migration 000002 — mobil kimlik Sanctum token'ı, session değil),
    yani kutu işaretlense de hiçbir şey yapmazdı. Sahte his vermektense göstermemek doğru.
--}}
<x-site.kimlik-kabuk kulak="Hesap" baslik="Tekrar hoş geldiniz."
    aciklama="Abonelik, fatura ve işletme bilgilerinizi yönetmek için giriş yapın."
    altYazi="Kurye ve tezgâh hesapları web'e girmez — onlar mobil uygulamadan firma koduyla giriş yapar.">

    <form wire:submit="authenticate" novalidate>
        <x-site.alan etiket="E-posta" :hata="$errors->first('email')" id="g-eposta">
            <input id="g-eposta" class="gir @error('email') yanlis @enderror" type="email" inputmode="email"
                autocomplete="email" placeholder="mehmet@merkezsubayi.com" wire:model="email">
        </x-site.alan>

        <div class="alan" x-data="{ gor: false }">
            <label class="etk" for="g-parola">Parola</label>
            <div class="gir-sarma">
                <input id="g-parola" class="gir @error('password') yanlis @enderror"
                    :type="gor ? 'text' : 'password'" type="password"
                    autocomplete="current-password" placeholder="••••••••" wire:model="password">
                <button type="button" class="gir-goz" @click="gor = !gor" aria-label="Parolayı göster">
                    <span x-show="!gor"><x-site.ikon ad="goz" boy="19" kalin="1.9" /></span>
                    <span x-show="gor" x-cloak><x-site.ikon ad="gozKapali" boy="19" kalin="1.9" /></span>
                </button>
            </div>
            @error('password')
                <span class="hata"><x-site.ikon ad="uyari" boy="14" kalin="2.3" />{{ $message }}</span>
            @enderror
            <span class="yardim">
                <a class="kimlik-link" href="{{ route('site.parola') }}">Parolamı unuttum</a>
            </span>
        </div>

        <button class="dg dg-a tam" type="submit" style="margin-top:24px" wire:loading.attr="disabled">
            <span wire:loading.remove wire:target="authenticate">Giriş yap</span>
            <span class="donen" wire:loading wire:target="authenticate"></span>
        </button>
    </form>

    <div class="kimlik-ayrac"><span>Hesabınız yok mu?</span></div>
    <a class="dg dg-c tam" href="{{ route('subscription.register') }}">
        İşletmenizi açın · {{ $this->denemeGun }} gün ücretsiz
    </a>
</x-site.kimlik-kabuk>
