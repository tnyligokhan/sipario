{{--
    Sss — SSS akordiyonu. liste: [{s: soru, c: cevap}, ...]. acikVar: ilk soru açık başlasın mı.
    cevap alanı (c) ham HTML olarak basılır — çağıran taraf metni önceden temizlemeli.
--}}
@props(['liste', 'acikVar' => false])
<div class="sss" x-data="{ acik: {{ $acikVar ? 0 : -1 }} }">
    @foreach($liste as $i => $x)
        <div class="sss-satir" :class="{ on: acik === {{ $i }} }">
            <button type="button" class="sss-bas" @click="acik = acik === {{ $i }} ? -1 : {{ $i }}"
                :aria-expanded="acik === {{ $i }}">
                <span class="h4">{{ $x['s'] }}</span>
                <span class="sss-isaret">
                    <x-site.ikon ad="arti" boy="17" kalin="2.4" x-show="acik !== {{ $i }}" />
                    <x-site.ikon ad="eksi" boy="17" kalin="2.4" x-show="acik === {{ $i }}" x-cloak />
                </span>
            </button>
            <div class="sss-govde gvd" x-show="acik === {{ $i }}" x-cloak>{!! $x['c'] !!}</div>
        </div>
    @endforeach
</div>
