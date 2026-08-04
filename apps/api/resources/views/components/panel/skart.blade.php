{{--
    İstatistik kartı. Dashboard'daki .skartlar grid'inin her hücresi.
    Kullanım:
    <div class="skartlar">
        <x-panel.skart etiket="Aktif Abone" deger="128" alt="399,00 ₺/ay plan" />
        <x-panel.skart etiket="Bu Ay Net" deger="+12.400,00 ₺" kip="arti" alt="Gelir 40.000 ₺ · Gider 27.600 ₺" />
    </div>
    kip: "arti" (yeşil) veya "eksi" (kırmızı) — yalnız para/fark değerlerinde kullan.
--}}
@props(['etiket', 'deger', 'alt' => null, 'kip' => null])

<div {{ $attributes->merge(['class' => 'skart']) }}>
    <div class="skart-l">{{ $etiket }}</div>
    <div class="skart-v tab @if ($kip) {{ $kip }} @endif">{{ $deger }}</div>
    @if ($alt)
        <div class="skart-alt">{{ $alt }}</div>
    @endif
</div>
