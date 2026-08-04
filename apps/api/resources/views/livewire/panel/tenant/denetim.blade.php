{{-- Denetim sekmesi — bu bayide yapılan panel eylemleri. SALT-OKUNUR. --}}
@use('App\Livewire\Panel\Concerns\Bicim')
<div class="dikey">
    <x-panel.kart baslik="Denetim" ikon="belge" :adet="$denetim->total().' kayıt'">
        <div class="modal-bilgi" style="margin:14px 18px">
            <x-panel.ikon ad="bilgi" boy="15" />
            <span>Bu bayide yapılan panel eylemleri. Kayıtlar yalnız eylem türü ve hedef kimlik
                taşır — müşteri/para DEĞERİ denetim günlüğüne yazılmaz (KVKK).</span>
        </div>

        @if ($denetim->isEmpty())
            <x-panel.bos metin="Bu bayide panel eylemi kaydı yok." />
        @else
            <x-panel.tablo>
                <thead>
                    <tr><th>Tarih</th><th>Admin</th><th>Eylem</th><th>Ayrıntı</th></tr>
                </thead>
                <tbody>
                    @foreach ($denetim as $k)
                        <tr>
                            <td class="tab">{{ Bicim::tarihSaat($k->created_at) }}</td>
                            <td>{{ $k->admin ?? '—' }}</td>
                            <td class="kalin">{{ $k->action }}</td>
                            <td class="soluk">{{ $k->detail ?? '—' }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
    </x-panel.kart>

    {{ $denetim->links('vendor.pagination.panel-basit') }}
</div>
