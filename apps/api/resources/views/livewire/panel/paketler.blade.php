{{--
    PAKETLER (tasarım `09-PlanDuzenleModal.jsx` · Paketler).
    Üç kart: Abonelik Planı · Ek Paketler · Son Tanımlamalar. Metinler tasarımdan birebir;
    tek ekleme "Yıllık ücret" satırıdır (bkz. _plan-modal.blade.php başlığı).
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

<x-panel.layout>
    <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
    <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

    <x-panel.ust baslik="Paketler" alt="Abonelik planı, ek paketler ve firmalara tanımlamalar">
        <x-slot:sag>
            @if ($superadmin)
                <button type="button" class="btn birincil" wire:click="tanimlaModalAc">
                    <x-panel.ikon ad="arti" boy="15" /> Ek Paket Tanımla
                </button>
            @endif
        </x-slot:sag>
    </x-panel.ust>

    <x-panel.kart baslik="Abonelik Planı" adet="tek plan" style="margin-bottom:12px">
        <div class="bilgi-satirlar">
            <x-panel.bilgi-satir k="Plan adı">{{ $planAdi }}</x-panel.bilgi-satir>
            <x-panel.bilgi-satir k="Aylık ücret"><span class="tab">{{ Bicim::tl($aylikKurus) }}</span></x-panel.bilgi-satir>
            <x-panel.bilgi-satir k="Yıllık ücret"><span class="tab">{{ Bicim::tl($yillikKurus) }}</span></x-panel.bilgi-satir>
            <x-panel.bilgi-satir k="Deneme süresi"><span class="tab">{{ $denemeGun }} gün</span></x-panel.bilgi-satir>
            <x-panel.bilgi-satir k="Aylık oto-sıralama hakkı"><span class="tab">{{ $hakAy }}</span></x-panel.bilgi-satir>
            <x-panel.bilgi-satir k="Kurye hesabı"><span class="tab">{{ $kuryeLimiti }}</span></x-panel.bilgi-satir>
        </div>
        @if ($superadmin)
            <x-slot:aksiyonlar>
                <button type="button" class="btn" wire:click="planModalAc">Planı Düzenle</button>
            </x-slot:aksiyonlar>
        @endif
    </x-panel.kart>

    <x-panel.kart baslik="Ek Paketler" :adet="$satistaSayisi . ' aktif'" style="margin-bottom:12px">
        @if ($paketler->isEmpty())
            <x-panel.bos metin="Henüz ek paket tanımlı değil." />
        @else
            <x-panel.tablo>
                <thead>
                    <tr>
                        <th>Paket</th>
                        <th>Tür</th>
                        <th class="sag">Kapsam</th>
                        <th class="sag">Ücret</th>
                        <th>Durum</th>
                        <th class="sag">İşlem</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($paketler as $p)
                        <tr wire:key="paket-{{ $p->id }}">
                            <td class="kalin">{{ $p->name }}</td>
                            <td>{{ $p->type === 'credits' ? 'Oto-sıralama' : 'Ek kurye' }}</td>
                            <td class="sag tab">{{ $p->quantity }} {{ $p->type === 'credits' ? 'hak' : 'hesap' }}</td>
                            <td class="sag kalin tab">{{ Bicim::tl($p->price_kurus) }}</td>
                            <td><span class="rozet {{ $p->active ? 'aktif' : 'iptal' }}">{{ $p->active ? 'Satışta' : 'Pasif' }}</span></td>
                            <td class="sag">
                                @if ($superadmin)
                                    <button type="button" class="link-btn" wire:click="paketModalAc('{{ $p->id }}')">Düzenle</button>
                                @else
                                    <span class="soluk">—</span>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
        @if ($superadmin)
            <x-slot:aksiyonlar>
                <button type="button" class="btn" wire:click="paketModalAc">
                    <x-panel.ikon ad="arti" boy="15" /> Ek Paket Ekle
                </button>
            </x-slot:aksiyonlar>
        @endif
    </x-panel.kart>

    <x-panel.kart baslik="Son Tanımlamalar" :adet="count($tanimlamalar) . ' kayıt'">
        @if ($tanimlamalar === [])
            <x-panel.bos metin="Henüz firmalara ek paket tanımlanmadı." />
        @else
            <x-panel.tablo>
                <thead>
                    <tr>
                        <th>Tarih</th>
                        <th>Firma</th>
                        <th>Paket</th>
                        <th class="sag">Tutar</th>
                        <th>Tahsilat</th>
                        <th>Not</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($tanimlamalar as $t)
                        <tr wire:key="tanim-{{ $t['id'] }}">
                            <td class="tab" style="white-space:nowrap">{{ $t['tarih'] }}</td>
                            <td>
                                <a href="{{ route('panel.tenant', $t['tenant_id']) }}" class="link-btn" style="color:var(--ink)">{{ $t['firma'] }}</a>
                            </td>
                            <td>{{ $t['paket'] }}</td>
                            <td class="sag kalin tab">
                                @if ($t['bedelsiz'])
                                    <span class="soluk">—</span>
                                @else
                                    {{ Bicim::tl($t['tutar_kurus']) }}
                                @endif
                            </td>
                            <td>{{ $t['tahsil'] }}</td>
                            <td class="soluk">{{ $t['not'] }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
    </x-panel.kart>

    @if ($planModalAcik)
        @include('livewire.panel.para._plan-modal')
    @endif
    @if ($paketModalAcik)
        @include('livewire.panel.para._paket-modal')
    @endif
    @if ($tanimlaModalAcik)
        @include('livewire.panel.para._tanimla-modal')
    @endif
</x-panel.layout>
