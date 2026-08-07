{{--
    Panel hesapları — TASARIMDA YOK. İşlev AYNEN korundu, yalnız tasarım diline geçirildi.
    Yetki kapısı bileşenin İÇİNDEDİR (mount + her eylem); bu ekranın görünür olması bir izin değildir.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

<div>
    <x-panel.layout>
        <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
        <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

        <x-panel.ust baslik="Panel Hesapları" :alt="$adminler->count().' hesap'" />

        @if ($bildirim)
            @php($stil = $bildirim['tur'] === 'ok'
                ? 'margin-bottom:12px'
                : 'margin-bottom:12px;background:var(--danger-soft);color:var(--danger)')
            <div class="modal-bilgi" style="{{ $stil }}" role="status">
                <x-panel.ikon :ad="$bildirim['tur'] === 'ok' ? 'bilgi' : 'uyari'" boy="15" />
                <span>{{ $bildirim['mesaj'] }}</span>
            </div>
        @endif

        @if ($yeniParola)
            <div class="modal-bilgi" style="margin-bottom:12px">
                <x-panel.ikon ad="kilit" boy="15" />
                <span>
                    Yeni hesabın parolası: <b class="tab">{{ $yeniParola }}</b> —
                    <b>Bir kez gösterilir ve saklanmaz</b>; şimdi güvenli bir yere alın.
                </span>
            </div>
        @endif

        <div class="dikey">
            <x-panel.kart baslik="Yeni hesap" ikon="arti">
                <div class="modal-govde">
                    <x-panel.alan label="Ad *">
                        <input class="girdi" type="text" wire:model="ad">
                    </x-panel.alan>
                    @error('ad')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

                    <x-panel.alan label="E-posta *">
                        <input class="girdi" type="text" wire:model="email" autocomplete="off">
                    </x-panel.alan>
                    @error('email')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

                    <x-panel.alan label="Rol">
                        <x-panel.radyolar :secenekler="$roller" :secili="$rol" wire:model="rol" />
                    </x-panel.alan>
                    @error('rol')<div style="color:var(--danger);font-size:12px">{{ $message }}</div>@enderror

                    <div class="modal-bilgi">
                        <x-panel.ikon ad="bilgi" boy="15" />
                        <span>
                            <b>Süper yönetici:</b> abonelik, kilit, modül, kurye, patron şifresi ve hesap yönetimi.
                            <b>Destek:</b> görüntüleme + veri girişi (müşteri/ürün, CSV aktarımı).
                        </span>
                    </div>
                </div>

                <x-slot:aksiyonlar>
                    <button type="button" class="btn birincil" wire:click="ekle">Hesap Aç</button>
                </x-slot:aksiyonlar>
            </x-panel.kart>

            <x-panel.kart baslik="Hesaplar" ikon="uyeler" :adet="$adminler->count().' kayıt'">
                <div class="modal-bilgi" style="margin:14px 18px">
                    <x-panel.ikon ad="bilgi" boy="15" />
                    <span>Hesaplar SİLİNMEZ, pasifleştirilir — denetim günlüğündeki
                        &ldquo;kim yaptı&rdquo; sütunu boşalmasın.</span>
                </div>

                @if ($adminler->isEmpty())
                    <x-panel.bos metin="Hesap yok." />
                @else
                    <x-panel.tablo>
                        <thead>
                            <tr>
                                <th>Ad</th><th>E-posta</th><th>Rol</th>
                                <th>Durum</th><th>Son giriş</th><th class="sag">İşlem</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($adminler as $admin)
                                <tr>
                                    <td>
                                        <div class="kalin">{{ $admin->name }}</div>
                                        @if ($admin->id === $benimId)
                                            <div class="soluk" style="font-size:12.5px">siz</div>
                                        @endif
                                    </td>
                                    <td class="soluk">{{ $admin->email }}</td>
                                    <td>
                                        <select
                                            class="girdi"
                                            style="width:auto"
                                            wire:change="rolDegistir('{{ $admin->id }}', $event.target.value)"
                                        >
                                            @foreach ($roller as $deger => $etiket)
                                                <option value="{{ $deger }}" @selected($admin->role === $deger)>{{ $etiket }}</option>
                                            @endforeach
                                        </select>
                                    </td>
                                    <td>
                                        @if ($admin->pasifMi())
                                            <span class="rozet iptal">pasif</span>
                                        @else
                                            <span class="rozet aktif">aktif</span>
                                        @endif
                                    </td>
                                    <td class="tab">{{ Bicim::tarihSaat($admin->last_login_at) }}</td>
                                    <td class="sag">
                                        @if ($admin->pasifMi())
                                            <button type="button" class="link-btn"
                                                    wire:click="aktiflik('{{ $admin->id }}', true)">Yeniden aç</button>
                                        @else
                                            <button type="button" class="link-btn"
                                                    wire:click="aktiflik('{{ $admin->id }}', false)">Pasifleştir</button>
                                        @endif
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </x-panel.tablo>
                @endif
            </x-panel.kart>
        </div>
    </x-panel.layout>
</div>
