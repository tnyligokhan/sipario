{{--
    Üye detayı kabuğu (tasarım `07-Uyeler.jsx` · UyeDetay). Geri bağlantısı + başlık + sekme çipleri
    + açık sekmenin parçası. Tasarımın iki sütunlu düzeni "ozet" parçasındadır.

    Sekmeler tasarımda YOKtu: tasarım tek bir firma kartı gösteriyordu, sunucuda bayinin iş verisi
    (müşteri/sipariş/defter/ürün/denetim) de aynı ekrandan görülüyor ve BRIEF bunu zorunlu kılıyor.
    Çipler tasarımın kendi bileşenidir — yeni bir görsel dil icat edilmedi.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

@php
    $tenant = $detail['tenant'];
    $tarih = Bicim::tarihKisa(...);
    $yer = $tenant->city
        ? $tenant->city.($tenant->district ? ' / '.$tenant->district : '')
        : $tenant->slug;

    $sekmeEtiketleri = [
        'ozet' => 'Özet',
        'musteriler' => 'Müşteriler · '.$sayilar['musteri'],
        'siparisler' => 'Siparişler · '.$sayilar['siparis'],
        'defter' => 'Defter · '.$sayilar['defter'],
        'urunler' => 'Ürünler · '.$sayilar['urun'],
        'denetim' => 'Denetim · '.$sayilar['denetim'],
    ];
@endphp

<div>
    <x-panel.layout>
        <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
        <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

        <a href="{{ route('panel.tenants') }}" class="geri">
            <x-panel.ikon ad="geri" boy="15" /> Üyeler
        </a>

        <x-panel.ust
            :baslik="$tenant->name"
            :alt="$yer.' · kayıt '.$tarih($tenant->created_at)"
            style="margin-bottom:16px"
        >
            <x-slot:sag><x-panel.rozet :durum="$tenant->status" /></x-slot:sag>
        </x-panel.ust>

        <x-panel.cipler
            :secenekler="$sekmeEtiketleri"
            :secili="$sekme"
            wire:model="sekme"
            style="margin-bottom:14px"
        />

        {{-- Sonuç bildirimi. Sessiz kalması yasak: kilitli bayi ('locked') ve bayat yazım ('stale')
             gibi durumlarda panel "kaydettim" der ama hiçbir şey yazılmaz. --}}
        @if ($bildirim)
            @php($bildirimStil = $bildirim['tur'] === 'ok'
                ? 'margin-bottom:12px'
                : 'margin-bottom:12px;background:var(--danger-soft);color:var(--danger)')
            <div class="modal-bilgi" style="{{ $bildirimStil }}" role="status">
                <x-panel.ikon :ad="$bildirim['tur'] === 'ok' ? 'bilgi' : 'uyari'" boy="15" />
                <span>{{ $bildirim['mesaj'] }}</span>
            </div>
        @endif

        @if ($newPassword)
            <div class="modal-bilgi" style="margin-bottom:12px">
                <x-panel.ikon ad="kilit" boy="15" />
                <span>
                    Patronun yeni parolası: <b class="tab">{{ $newPassword }}</b> —
                    <b>bir kez gösterilir ve saklanmaz.</b> Şimdi güvenli bir yere alın.
                </span>
            </div>
        @endif

        {{-- Modallar sekmenin İÇİNDEN basılır (ozet parçası), buradan DEĞİL: ikisi de yalnız Özet
             sekmesinde var olan verilere (`$kuryeKota`) bakıyor ve `uzatAcik`/`kuryeAcik` kilitsiz
             public alanlardır — istemci bunları başka bir sekmedeyken true'ya çevirebilir. --}}
        @include('livewire.panel.tenant.'.$sekme)
    </x-panel.layout>
</div>
