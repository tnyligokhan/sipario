{{--
    Ana eylem düğmesi — sitedeki `.dg-a` (dolu mor) ve `.dg-c` (mürekkep kontur) karşılığı.

    NEDEN DOLGU `<td>`DE, `<a>`DA DEĞİL: Outlook'un Word çizicisi `<a>` üzerindeki `padding`i
    güvenilir uygulamaz — düğme "yazının etrafında hiç boşluk yok" diye çıkar. `<td>` dolgusu
    ise her istemcide çalışır. `<a>`ya `display:block` verilerek tıklanabilir alan hücrenin
    iç kutusunun tamamına yayıldı; yoksa yalnız harflerin üstü tıklanır olurdu.

    VML (`v:roundrect`) BİLEREK YOK: sabit piksel genişliği ister, Türkçe metin uzunluğu
    şablondan şablona değişir ve yanlış genişlik düğmeyi kırpar. Karşılığında Outlook'ta
    köşeler keskin çıkar — "Levha" dilinde kabul edilebilir bir kayıp.
--}}
@props(['url', 'tur' => 'a'])
@php
    $dolu = $tur === 'a';
@endphp
<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0 18px 0;border-collapse:separate;">
    <tr>
        <td align="center"
            @if ($dolu) bgcolor="#5A45F0" @endif
            style="border-radius:5px;padding:15px 26px;{{ $dolu ? 'background:#5A45F0;' : 'border:1.5px solid #16131C;' }}"
            @class(['e-pano' => ! $dolu])>
            <a href="{{ $url }}"
               style="display:block;font-family:'Hanken Grotesk','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:15.5px;font-weight:700;letter-spacing:-0.01em;line-height:1.1;text-decoration:none;color:{{ $dolu ? '#ffffff' : '#16131C' }};"
               @class(['e-murekkep' => ! $dolu])>{{ $slot }}</a>
        </td>
    </tr>
</table>
