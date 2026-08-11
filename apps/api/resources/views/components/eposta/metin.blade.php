{{--
    Gövde paragrafı. `son` işaretlenirse alt boşluk kalkar (bloklar arası çift boşluk olmasın).
    Renk `--murekkep-2`: sitedeki `.gvd` ile aynı — başlıktan bir ton açık, gövde metni.
--}}
@props(['son' => false])
<p class="e-metin" style="margin:0 0 {{ $son ? '0' : '14px' }} 0;font-family:'Hanken Grotesk','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:16px;line-height:1.62;color:#413B4C;">{{ $slot }}</p>
