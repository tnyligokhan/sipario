{{--
    GELİR-GİDER (tasarım `10-MasrafEkleModal.jsx` · GelirGider).
    Üst nottan ("Gelir ödemelerden otomatik hesaplanır") boş durum cümlelerine kadar metinler
    tasarımdan birebir. Tek ekleme: aylık net trend grafiği (kit `x-panel.grafik-cizgi`).
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

<x-panel.layout>
    <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
    <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

    <x-panel.ust baslik="Gelir-Gider" alt="Gelir ödemelerden otomatik hesaplanır">
        <x-slot:sag>
            @if ($superadmin)
                <button type="button" class="btn birincil" wire:click="masrafModalAc">
                    <x-panel.ikon ad="arti" boy="15" /> Masraf Ekle
                </button>
            @endif
        </x-slot:sag>
    </x-panel.ust>

    <x-panel.kart baslik="Aylık Net" ikon="gelirgider" style="margin-bottom:12px">
        <div style="padding:16px 18px">
            <x-panel.grafik-cizgi :veri="$trend" birim="₺" :ozet="$trendOzeti" />
        </div>
    </x-panel.kart>

    <div class="gg-yerlesim">
        <x-panel.kart baslik="Aylık Özet">
            @if ($ozet === [])
                <x-panel.bos metin="Henüz kayıt yok. Ödemeler ve masraflar girildikçe aylık özet burada oluşur." />
            @else
                <x-panel.tablo>
                    <thead>
                        <tr>
                            <th>Ay</th>
                            <th class="sag">Gelir</th>
                            <th class="sag">Gider</th>
                            <th class="sag">Net</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($ozet as $s)
                            <tr
                                wire:key="ay-{{ $s['ay'] }}"
                                class="satir-tik ay-satir @if ($s['ay'] === $seciliAy) secili @endif"
                                wire:click="ayaGec('{{ $s['ay'] }}')"
                            >
                                <td class="kalin">{{ Bicim::ayAdi($s['ay']) }}</td>
                                <td class="sag tab">{{ Bicim::tl($s['gelir_kurus']) }}</td>
                                <td class="sag tab">{{ Bicim::tl($s['gider_kurus']) }}</td>
                                <td class="sag kalin tab {{ $s['net_kurus'] < 0 ? 'eksi' : 'arti' }}">
                                    {{ Bicim::tlNet($s['net_kurus']) }}
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </x-panel.tablo>
            @endif
        </x-panel.kart>

        <x-panel.kart :baslik="$seciliAyAdi . ' masrafları'" :adet="Bicim::tl($kalemToplami)">
            @if ($kalemler->isEmpty())
                <x-panel.bos metin="Bu ay masraf kaydı yok." />
            @else
                <x-panel.tablo>
                    <tbody>
                        @foreach ($kalemler as $m)
                            <tr wire:key="masraf-{{ $m->id }}">
                                <td>
                                    <div class="kalin">{{ $m->category }}</div>
                                    @if ($m->note)
                                        <div class="soluk" style="font-size:12.5px">{{ $m->note }}</div>
                                    @endif
                                </td>
                                <td class="soluk tab" style="white-space:nowrap">{{ Bicim::tarihKisa($m->spent_on) }}</td>
                                <td class="sag kalin tab">{{ Bicim::tl($m->amount_kurus) }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </x-panel.tablo>
            @endif
        </x-panel.kart>
    </div>

    @if ($modalAcik)
        @include('livewire.panel.para._masraf-modal')
    @endif
</x-panel.layout>
