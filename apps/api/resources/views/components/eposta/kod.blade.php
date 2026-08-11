{{--
    Tek başına duran, KOPYALANMAK İÇİN var olan değer: firma kodu, havale referansı, geçici
    parola. Büyük, mono, seçilebilir, etrafı boş.

    Neden ayrı bir bileşen: bu değerler bir tablo satırının içinde kaybolur. Bayi telefonda
    postayı açıp bu değeri elle yazacak ya da basılı tutup kopyalayacak — o eylem için hedefin
    büyük ve tek başına olması gerekir. `user-select` ZORLANMADI (istemciler yok sayar); iş
    puntoyla ve boşlukla çözüldü.
--}}
@props(['etiket' => ''])
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:4px 0 18px 0;border-collapse:collapse;">
    <tr>
        <td class="e-kod" align="center" style="background:#EBE6DF;border:1.5px dashed #C6BDB0;border-radius:6px;padding:18px 16px;">
            @if ($etiket !== '')
                <div class="e-sonuk" style="margin:0 0 7px 0;font-family:'JetBrains Mono',ui-monospace,SFMono-Regular,Consolas,'Liberation Mono',monospace;font-size:10.5px;font-weight:500;letter-spacing:0.14em;text-transform:uppercase;color:#7B7486;">{{ $etiket }}</div>
            @endif
            <div style="font-family:'JetBrains Mono',ui-monospace,SFMono-Regular,Consolas,'Liberation Mono',monospace;font-size:22px;font-weight:700;letter-spacing:0.04em;line-height:1.3;color:#16131C;word-break:break-all;">{{ $slot }}</div>
        </td>
    </tr>
</table>
