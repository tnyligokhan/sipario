{{-- Ilerleme — çok adımlı formlarda adım göstergesi. adimlar: string[]; aktif: 0 tabanlı index. --}}
@props(['adimlar', 'aktif'])
<ol class="ilerle">
    @foreach($adimlar as $i => $a)
        <li @class(['ilerle-adim', 'ok' => $i < $aktif, 'on' => $i === $aktif])>
            <span class="ilerle-no">
                @if($i < $aktif)
                    <x-site.ikon ad="onay" boy="13" kalin="3" />
                @else
                    {{ $i + 1 }}
                @endif
            </span>
            <span class="ilerle-ad">{{ $a }}</span>
        </li>
    @endforeach
</ol>
