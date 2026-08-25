Ödemenizi bulamadık, birlikte bakalım
=====================================

{{ $isletme }} için {{ $beyanTarihi }} tarihinde bildirdiğiniz ödemeyi banka hesabımızda
eşleştiremedik. Bu çoğu zaman bir aksaklıktan olur, bir sorun olduğundan değil.

Bildirim tarihi  : {{ $beyanTarihi }}
Bildirilen tutar : {{ $tutar }}
Referans         : {{ $referans }}
@if ($not !== '')

Notumuz: {{ $not }}
@endif

EN SIK KARŞILAŞTIĞIMIZ ÜÇ SEBEP
1) Havale açıklamasına referans kodu yazılmamış olabilir - bu durumda ödeme sistemde sizin
   adınıza bağlanamaz.
2) Para henüz bankaya düşmemiş olabilir; bazı havaleler bir iş günü sürer.
3) Tutar bildirdiğinizden farklı gelmiş olabilir (banka masrafı gibi).

Ödemeyi yaptıysanız bu iletiyi yanıtlayıp bankanızın işlem numarasını ya da tarih-saat bilgisini
yazın; hesabımızda arayıp elle eşleştirelim. Henüz ödemediyseniz şu adresten güncel bilgilerle
yeniden başlayabilirsiniz:

{{ $abonelikUrl }}

Bu sırada verileriniz olduğu gibi duruyor; hiçbir kaydınız silinmez.

Kolay gelsin,
Sipario ekibi
