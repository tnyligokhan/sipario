{{--
    Numaralı adım listesi — "şimdi ne yapmalıyım" sorusunun cevabı.

    `<ol>` KULLANILMADI: Outlook ve bazı web istemcileri liste girintisini ve madde imini
    öngörülemez biçimde çizer, numaralar metne yapışır ya da iki kat girinti alır. Tablo +
    elle çizilen mor numara rozeti her yerde aynı görünür ve rozet markanın mor karesini
    tekrarlar (aynı dil, ikinci kez).

    Kullanım: <x-eposta.adimlar :adimlar="['Uygulamayı indirin', 'Ürünlerinizi girin']" />
--}}
@props(['adimlar' => []])
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:6px 0 18px 0;border-collapse:collapse;">
    @foreach ($adimlar as $i => $adim)
        <tr>
            <td width="26" valign="top" style="width:26px;padding:0 0 12px 0;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                        <td width="22" align="center" bgcolor="#EAE6FE" class="e-kutu-mor" style="width:22px;height:22px;background:#EAE6FE;border-radius:6px;font-family:'Sora','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:12px;font-weight:800;color:#4433C4;line-height:22px;">{{ $i + 1 }}</td>
                    </tr>
                </table>
            </td>
            <td valign="top" class="e-metin" style="padding:1px 0 12px 11px;font-family:'Hanken Grotesk','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:15.5px;line-height:1.5;color:#413B4C;">{{ $adim }}</td>
        </tr>
    @endforeach
</table>
