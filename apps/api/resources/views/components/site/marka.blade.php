{{-- Marka — Sipario logosu: S işareti + wordmark, TEK GÖRSEL.
     `koyu`: koyu zemin varyantı (yazı krem, harflerin içi saydam). Zemin sunucu tarafında
     belirlenir (`body[data-koyu]`), istemcide dönmez — bu yüzden iki görseli birden basıp
     CSS ile gizlemeye gerek yok, doğru dosya baştan seçilir. --}}
@props(['boy' => 34, 'koyu' => false])
<span class="marka">
    <img class="marka-logo"
         src="{{ \App\Support\Varlik::url($koyu ? 'img/sipario-logo-acik.png' : 'img/sipario-logo.png') }}"
         alt="Sipario"
         width="{{ (int) round($boy * 697 / 199) }}" height="{{ (int) $boy }}">
</span>
