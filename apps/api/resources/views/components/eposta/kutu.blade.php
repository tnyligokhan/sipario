{{--
    Renkli bilgi kutusu — sitedeki `.kutu-*` karşılığı. İkon YOK (SVG silinir); ayrımı yalnız
    zemin rengi taşımaz, kutunun başında KALIN BİR ETİKET metni vardır. Gerekçe WCAG 1.4.1:
    anlamı yalnız renge yükleyen bir uyarı, renk körü okuyucuda düz bir paragraftır.

    tur: mor (bilgi) · yesil (olumlu) · sari (dikkat) · kirmizi (sorun)
--}}
@props(['tur' => 'mor', 'etiket' => ''])
@php
    $palet = [
        'mor' => ['#EAE6FE', '#4433C4'],
        'yesil' => ['#DFF1E8', '#1B8F60'],
        'sari' => ['#F6EEDA', '#A8720F'],
        'kirmizi' => ['#FAE6E6', '#D3383E'],
    ];
    [$zemin, $yazi] = $palet[$tur] ?? $palet['mor'];
@endphp
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:4px 0 18px 0;border-collapse:collapse;">
    <tr>
        <td class="e-kutu-{{ $tur }}" bgcolor="{{ $zemin }}" style="background:{{ $zemin }};border-radius:5px;padding:15px 17px;font-family:'Hanken Grotesk','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:14.5px;line-height:1.5;color:{{ $yazi }};">
            @if ($etiket !== '')
                <strong style="color:{{ $yazi }};">{{ $etiket }}</strong>
            @endif
            {{ $slot }}
        </td>
    </tr>
</table>
