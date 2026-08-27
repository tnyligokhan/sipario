{{--
    TASARIMDA YOK — elle bayi açma (BRIEF md. 3). Alanlar siteden kayıt akışının aynısıdır;
    gerekçesi `App\Livewire\Panel\Forms\UyeForm` belge başlığında.

    Kullanıcı adı alanı YOK: patronun mobil kullanıcı adı her bayide 'patron'dur ve bilgi
    kutusunda yazılıdır — operatör telefonda ne söyleyeceğini modaldan okur.
--}}
<x-panel.modal baslik="Yeni Üye" wire:click="uyeKapat">
    <div class="modal-bilgi">
        <x-panel.ikon ad="bilgi" boy="15" />
        <span>
            Bayi <b>deneme süresiyle</b> açılır; abonelik ve kilit yönetimi üye detayından yürür.
            Patron uygulamaya <b>firma kodu</b>, <b class="tab">patron</b> kullanıcı adı ve
            aşağıdaki parolayla girer — mobilde e-posta sorulmaz.
        </span>
    </div>

    <x-panel.alan label="İşletme adı">
        <input class="girdi" type="text" wire:model.blur="uyeForm.isletme" placeholder="örn. Aslan Su Bayii">
    </x-panel.alan>
    @error('uyeForm.isletme')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <x-panel.alan label="Firma kodu">
        <input class="girdi tab" type="text" wire:model.blur="uyeForm.kod" placeholder="aslansu" autocomplete="off">
    </x-panel.alan>
    @error('uyeForm.kod')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <x-panel.alan label="Yetkili (ad soyad)">
        <input class="girdi" type="text" wire:model="uyeForm.yetkili" placeholder="örn. Hasan Aslan">
    </x-panel.alan>
    @error('uyeForm.yetkili')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <x-panel.alan label="E-posta">
        <input class="girdi" type="text" wire:model="uyeForm.eposta" placeholder="hasan@aslansu.com" autocomplete="off">
    </x-panel.alan>
    @error('uyeForm.eposta')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <x-panel.alan label="Telefon (isteğe bağlı)">
        <input class="girdi tab" type="text" wire:model="uyeForm.telefon" placeholder="0532 111 22 33">
    </x-panel.alan>
    @error('uyeForm.telefon')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <x-panel.alan label="Patron parolası">
        <input class="girdi" type="text" wire:model="uyeForm.parola" placeholder="en az 8 karakter" autocomplete="off">
    </x-panel.alan>
    @error('uyeForm.parola')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

    <label class="soluk" style="display:flex;align-items:center;gap:8px;font-size:12.5px;margin-top:4px">
        <input type="checkbox" wire:model="uyeForm.posta">
        Firma kodunu ve kullanıcı adını içeren hoş geldiniz e-postası gönder
    </label>

    <x-slot:alt>
        <button type="button" class="btn" wire:click="uyeKapat">Vazgeç</button>
        <button type="button" class="btn birincil" wire:click="uyeKaydet">Üyeyi Aç</button>
    </x-slot:alt>
</x-panel.modal>
