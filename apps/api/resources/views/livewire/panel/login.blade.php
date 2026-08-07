{{--
    Giriş ekranı (tasarım `05-Giris.jsx`). KENAR ÇUBUĞU YOK — bu view bilerek <x-panel.layout>
    KULLANMAZ, `.giris-sahne`yi doğrudan basar (bkz. components/panel/layout.blade.php belge başlığı).

    "Giriş Yap" düğmesinin pasifliği tasarımın etkileşim kararıdır (`disabled={!eposta || !sifre}`).
    Livewire'a bağlanmadı: `wire:model.live` her tuşa basışta ağ turu atardı ve giriş ekranı
    parolanın her harfini sunucuya göndermek için en kötü yerdir. Alpine yerel olarak bakar.
--}}
<div class="giris-sahne">
    <div style="display:flex;align-items:center;gap:10px">
        <div class="yk-mark" style="width:36px;height:36px;border-radius:11px">
            <x-panel.ikon ad="damla" boy="19" />
        </div>
        <span class="yk-ad" style="font-size:21px">Sipario</span>
    </div>

    <form
        class="giris-kart"
        wire:submit="authenticate"
        {{-- Başlangıç değeri SUNUCUDAN gelir. Sabit `false` verilseydi, başarısız bir denemeden
             sonra Livewire yeniden çizerken alanlar dolu kalır ama düğme pasifleşirdi ve kullanıcı
             tekrar denemek için bir harf yazmak zorunda kalırdı. --}}
        x-data="{ dolu: @js(trim($email) !== '' && $password !== '') }"
        x-on:input="dolu = $refs.eposta.value.trim() !== '' && $refs.sifre.value !== ''"
    >
        <div>
            <div class="giris-baslik">Yönetim Paneli</div>
            <div style="font-size:13px;color:var(--muted);margin-top:4px">Kurucu hesabınla giriş yap.</div>
        </div>

        <x-panel.alan label="E-posta">
            <input
                class="girdi"
                type="email"
                wire:model="email"
                x-ref="eposta"
                placeholder="ornek@sipario.app"
                autocomplete="username"
                autofocus
            >
        </x-panel.alan>

        <x-panel.alan label="Şifre">
            <input
                class="girdi"
                type="password"
                wire:model="password"
                x-ref="sifre"
                placeholder="••••••••"
                autocomplete="current-password"
            >
        </x-panel.alan>

        {{-- Hata NÖTRdür (kullanıcı numaralandırma sızdırmaz) ve tek yerde toplanır: bileşen hem
             kimlik hatasını hem hız sınırı uyarısını 'email' alanına yazar. --}}
        @error('email')
            <div class="giris-not" style="color:var(--danger);text-align:left">{{ $message }}</div>
        @enderror
        @error('password')
            <div class="giris-not" style="color:var(--danger);text-align:left">{{ $message }}</div>
        @enderror

        <button class="btn birincil blok" type="submit" x-bind:disabled="! dolu">Giriş Yap</button>
    </form>

    <div class="giris-not">Sipario iç yönetim aracı · yalnızca kurucular</div>
</div>
