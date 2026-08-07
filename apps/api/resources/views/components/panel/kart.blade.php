{{--
    Kullanım:
    <x-panel.kart baslik="Firma Bilgileri">
        ...gövde (tablo, bilgi-satir, vb.)...
        <x-slot:aksiyonlar><button class="btn">Düzenle</button></x-slot:aksiyonlar>
    </x-panel.kart>

    baslik yoksa kart-baslik satırı hiç basılmaz (bkz. UyeDetay'daki "Ödeme Geçmişi" gibi
    başlıksız kullanımlar için de baslik ver — orijinal tasarımda her kartın başlığı var).
--}}
@props(['baslik' => null, 'ikon' => null, 'adet' => null])

<div {{ $attributes->merge(['class' => 'kart']) }}>
    @if ($baslik)
        <div class="kart-baslik">
            @if ($ikon)
                <x-panel.ikon :ad="$ikon" boy="15" />
            @endif
            {{ $baslik }}
            @if ($adet)
                <span class="adet">{{ $adet }}</span>
            @endif
        </div>
    @endif

    {{ $slot }}

    @isset($aksiyonlar)
        <div class="aksiyonlar">{{ $aksiyonlar }}</div>
    @endisset
</div>
