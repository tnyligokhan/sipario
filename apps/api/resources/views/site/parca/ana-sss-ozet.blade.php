{{-- Ana sayfa · SSS özeti (09-sw-ana.jsx · SssOzetBlm): Başlangıç ve Ödeme gruplarından ikişer soru. --}}
@php($ozet = array_merge(array_slice($sw['sss'][0]['l'], 0, 2), array_slice($sw['sss'][1]['l'], 0, 2)))
<section class="blm">
    <div class="kap sss-kap">
        <x-site.blm-bas kulak="Sık sorulanlar" baslik="Akla ilk gelenler." />
        <x-site.sss :liste="$ozet" acik-var />
        <a class="dg dg-d sss-daha" href="{{ route('site.destek') }}">Tüm soruları gör<x-site.ikon ad="sag" boy="18" kalin="2.2" /></a>
    </div>
</section>
