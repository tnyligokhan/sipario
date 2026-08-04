{{--
    TASARIMDA YOK — kurye hesabı açma. BUGÜNE KADAR PANELDE (ve başka hiçbir yerde) kurye açmanın
    yolu yoktu; "3 kurye hesabı" yalnız fiyat sayfasındaki bir cümleydi. Kota kapısı
    `Provisioning::createCourier` içindeki `KuryeKotasi`dir — burada tekrarlanmaz, yalnız gösterilir.
--}}
@php($tenant = $detail['tenant'])

<x-panel.modal :baslik="'Kurye Hesabı Aç — '.$tenant->name" wire:click="kuryeKapat">
    <div class="modal-bilgi">
        <x-panel.ikon ad="bilgi" boy="15" />
        <span>
            Kurye uygulamaya <b>firma kodu</b> (<span class="tab">{{ $tenant->slug }}</span>),
            kullanıcı adı ve parolayla girer — e-posta sorulmaz.
            Kota: <b class="tab">{{ $kuryeKota['kullanilan'] }} / {{ $kuryeKota['limit'] }}</b>.
            Parola bir daha gösterilmez; şimdi kuryeye iletin.
        </span>
    </div>

    <x-panel.alan label="Ad soyad">
        <input class="girdi" type="text" wire:model="kuryeAd" placeholder="örn. Mehmet Demir">
    </x-panel.alan>
    @error('kuryeAd')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <x-panel.alan label="Kullanıcı adı">
        <input class="girdi" type="text" wire:model="kuryeKullanici" placeholder="mehmet" autocomplete="off">
    </x-panel.alan>
    @error('kuryeKullanici')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <x-panel.alan label="Parola">
        <input class="girdi" type="text" wire:model="kuryeParola" placeholder="en az 8 karakter" autocomplete="off">
    </x-panel.alan>
    @error('kuryeParola')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <x-panel.alan label="Telefon (isteğe bağlı)">
        <input class="girdi tab" type="text" wire:model="kuryeTelefon" placeholder="0532 111 22 33">
    </x-panel.alan>
    @error('kuryeTelefon')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <x-slot:alt>
        <button type="button" class="btn" wire:click="kuryeKapat">Vazgeç</button>
        <button
            type="button"
            class="btn birincil"
            wire:click="kuryeKaydet"
            @disabled($kuryeKota['kalan'] < 1)
        >Hesabı Aç</button>
    </x-slot:alt>
</x-panel.modal>
