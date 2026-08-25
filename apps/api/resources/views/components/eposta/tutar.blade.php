{{--
    Kahraman rakam — postanın tek bakışta okunması gereken sayısı (ödenen tutar, kalan gün).
    Sitedeki `.rakam` karşılığı: Sora 800, tablo rakamları, sıkı harf aralığı.

    `font-variant-numeric:tabular-nums` istemcilerin bir kısmında düşer; zarar yok — tek bir
    sayı gösterildiği için sütun hizalaması gerekmiyor, kural yalnız desteklendiğinde kazandırır.
--}}
@props(['etiket' => '', 'renk' => 'murekkep'])
@php
    $renkler = ['murekkep' => '#16131C', 'mor' => '#5A45F0', 'yesil' => '#1B8F60', 'kirmizi' => '#D3383E'];
    $c = $renkler[$renk] ?? $renkler['murekkep'];
@endphp
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:2px 0 16px 0;border-collapse:collapse;">
    <tr>
        <td>
            @if ($etiket !== '')
                <div class="e-sonuk" style="margin:0 0 4px 0;font-family:'JetBrains Mono',ui-monospace,SFMono-Regular,Consolas,'Liberation Mono',monospace;font-size:10.5px;font-weight:500;letter-spacing:0.14em;text-transform:uppercase;color:#7B7486;">{{ $etiket }}</div>
            @endif
            <div @class(['e-murekkep' => $renk === 'murekkep', 'e-mor-metin' => $renk === 'mor'])
                 style="font-family:'Sora','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:38px;font-weight:800;letter-spacing:-0.04em;line-height:1.05;color:{{ $c }};font-variant-numeric:tabular-nums;">{{ $slot }}</div>
        </td>
    </tr>
</table>
