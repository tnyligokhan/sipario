{{--
    Detay ekranlarındaki "k: v" satırı (bkz. .bilgi-satirlar). Değer serbest içerik alabilir
    (metin, rozet, renkli span) — slot olarak verilir.
    Kullanım:
    <div class="bilgi-satirlar">
        <x-panel.bilgi-satir k="Durum"><x-panel.rozet :durum="$firma->durum" /></x-panel.bilgi-satir>
        <x-panel.bilgi-satir k="Telefon"><span class="tab">{{ $firma->tel }}</span></x-panel.bilgi-satir>
    </div>
--}}
@props(['k'])

<div {{ $attributes->merge(['class' => 'bilgi-satir']) }}>
    <span class="k">{{ $k }}</span>
    <span class="v">{{ $slot }}</span>
</div>
