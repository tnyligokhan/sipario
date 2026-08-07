{{--
    Kullanım (thead/tbody'i çağıran ekran yazar — kit yalnız sarmalayıcıdır):
    <x-panel.tablo>
        <thead><tr><th>Firma</th><th class="sag">Bitiş</th></tr></thead>
        <tbody>
            @foreach ($firmalar as $f)
                <tr class="satir-tik" wire:click="ac({{ $f->id }})">
                    <td><div class="kalin">{{ $f->ad }}</div></td>
                    <td class="sag tab">{{ $f->bitis->format('d.m.Y') }}</td>
                </tr>
            @endforeach
        </tbody>
    </x-panel.tablo>
    Hücre yardımcı sınıfları: .sag (sağa yasla), .kalin (kalın), .soluk (muted), .tab (tabular rakam).
--}}
@props([])

<table {{ $attributes->merge(['class' => 'tablo']) }}>
    {{ $slot }}
</table>
