{{--
    Sayfa başlığı bloğu. Kullanım:
    <x-panel.ust baslik="Üyeler" alt="128 kayıtlı firma">
        <x-slot:sag><x-panel.ara-kutusu wire:model.live="arama" yertut="Firma, yetkili veya il ara…" /></x-slot:sag>
    </x-panel.ust>
    Detay ekranlarında "Geri" bağlantısını üstte, x-panel.ust'un DIŞINDA/ÜSTÜNDE koy
    (bkz. .geri sınıfı — <a href="{{ route(...) }}" class="geri"><x-panel.ikon ad="geri" boy="15" /> Üyeler</a>).
--}}
@props(['baslik', 'alt' => null])

<div {{ $attributes->merge(['class' => 'ust']) }}>
    <div>
        <h1>{{ $baslik }}</h1>
        @if ($alt)
            <div class="ust-alt">{{ $alt }}</div>
        @endif
    </div>
    @isset($sag)
        <div class="ust-sag">{{ $sag }}</div>
    @endisset
</div>
