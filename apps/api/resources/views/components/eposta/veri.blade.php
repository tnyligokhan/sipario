{{--
    Etiket → değer tablosu (sitedeki `.tbl`in posta karşılığı). Havale talimatı, ödeme özeti,
    hesap künyesi gibi "bakılıp okunan" bloklar için.

    İKİ SÜTUN, TEK SÜTUNA DÜŞMEZ: dar ekranda sütunları alt alta indirmek IBAN gibi uzun
    değerlerde etiketi değerden koparır. Bunun yerine etiket sütunu dar ve mono tutuldu, değer
    sütunu esner ve gerekirse sarar (`word-break`), yani hizalama her genişlikte korunur.

    Değerler `mono` bayrağıyla tek aralıklı yazılır — IBAN, referans kodu, firma kodu gibi
    KARAKTER KARAKTER okunan/kopyalanan alanlar için (sitedeki `.kod-v` disiplini).

    Kullanım: <x-eposta.veri :satirlar="['IBAN' => 'TR..', 'Tutar' => '5.988,00 ₺']" mono />
--}}
@props(['satirlar' => [], 'mono' => false])
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" class="e-duz" style="margin:4px 0 18px 0;background:#EBE6DF;border:1px solid #DED7CD;border-radius:5px;border-collapse:separate;">
    @foreach ($satirlar as $etiket => $deger)
        <tr>
            <td class="e-sonuk {{ ! $loop->last ? 'e-cizgi' : '' }}"
                style="padding:12px 16px;width:38%;vertical-align:top;font-family:'JetBrains Mono',ui-monospace,SFMono-Regular,Consolas,'Liberation Mono',monospace;font-size:10.5px;font-weight:500;letter-spacing:0.13em;text-transform:uppercase;color:#7B7486;{{ ! $loop->last ? 'border-bottom:1px solid #DED7CD;' : '' }}">{{ $etiket }}</td>
            <td class="e-murekkep {{ ! $loop->last ? 'e-cizgi' : '' }}"
                style="padding:12px 16px;vertical-align:top;font-family:{{ $mono ? "'JetBrains Mono',ui-monospace,SFMono-Regular,Consolas,'Liberation Mono',monospace" : "'Hanken Grotesk','Segoe UI',Roboto,Helvetica,Arial,sans-serif" }};font-size:{{ $mono ? '14px' : '15px' }};font-weight:700;line-height:1.45;color:#16131C;word-break:break-word;{{ ! $loop->last ? 'border-bottom:1px solid #DED7CD;' : '' }}">{{ $deger }}</td>
        </tr>
    @endforeach
</table>
