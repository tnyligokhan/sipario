{{--
    Denetim günlüğü — TASARIMDA YOK, BRIEF'in KVKK izi. İşlev AYNEN korundu, yalnız tasarım diline
    geçirildi. Her iki rol de görür: destek ekibinin kendi yaptığını (ve başkasının yaptığını)
    görmesi hesap verebilirliği zayıflatmaz, güçlendirir.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

<div>
    <x-panel.layout>
        <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
        <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

        <x-panel.ust baslik="Denetim Günlüğü" :alt="$kayitlar->total().' kayıt'">
            <x-slot:sag>
                <select class="girdi" style="width:auto" wire:model.live="eylem">
                    <option value="">Tüm eylemler</option>
                    @foreach ($eylemTurleri as $tur)
                        <option value="{{ $tur }}">{{ $tur }}</option>
                    @endforeach
                </select>
            </x-slot:sag>
        </x-panel.ust>

        <x-panel.kart>
            <div class="modal-bilgi" style="margin:14px 18px">
                <x-panel.ikon ad="bilgi" boy="15" />
                <span>Tüm bayilerdeki panel eylemleri. Kayıtlar yalnız eylem türü ve hedef kimlik
                    taşır; müşteri/para DEĞERİ günlüğe yazılmaz (KVKK).</span>
            </div>

            @if ($kayitlar->isEmpty())
                <x-panel.bos ikon="belge" metin="Kayıt yok." />
            @else
                <x-panel.tablo>
                    <thead>
                        <tr><th>Tarih</th><th>Admin</th><th>Bayi</th><th>Eylem</th><th>Ayrıntı</th></tr>
                    </thead>
                    <tbody>
                        @foreach ($kayitlar as $k)
                            <tr>
                                <td class="tab">{{ Bicim::tarihSaat($k->created_at) }}</td>
                                <td>{{ $k->admin ?? '—' }}</td>
                                <td>
                                    @if ($k->tenant_id)
                                        <a href="{{ route('panel.tenant', $k->tenant_id) }}">{{ $k->bayi ?? $k->tenant_id }}</a>
                                    @else
                                        <span class="soluk">(bayi üstü)</span>
                                    @endif
                                </td>
                                <td class="kalin">{{ $k->action }}</td>
                                <td class="soluk">{{ $k->detail ?? '—' }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </x-panel.tablo>
            @endif
        </x-panel.kart>

        {{ $kayitlar->links('vendor.pagination.panel-basit') }}
    </x-panel.layout>
</div>
