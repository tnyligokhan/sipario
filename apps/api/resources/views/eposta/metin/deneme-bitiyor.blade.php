@if ($kalanGun <= 1)
Deneme süreniz yarın bitiyor
============================
@else
Deneme sürenizin bitmesine {{ $kalanGun }} gün kaldı
====================================================
@endif

Merhaba {{ $yetkili }}, {{ $isletme }} için açtığınız deneme süresi {{ $bitisTarihi }} tarihinde
doluyor. Kalan süre: {{ $kalanGun }} gün.

SÜRE DOLUNCA NE OLUR: Yeni sipariş, tahsilat ve müşteri kaydı girilemez. Buraya kadar girdiğiniz
hiçbir şey silinmez - müşterileriniz, veresiye defteriniz ve geçmiş siparişleriniz sunucuda
durur ve abonelik başladığı an olduğu gibi geri gelir.

İşletme       : {{ $isletme }}
Deneme bitişi : {{ $bitisTarihi }}
@if ($yillikTutar !== '')
Yıllık abonelik: {{ $yillikTutar }}
@endif

Aboneliği başlatın: {{ $abonelikUrl }}

Havale/EFT ile ödeyebilir ya da bizi arayıp elden ödeme için sözleşebilirsiniz.

Ürünle ilgili bir sorunuz ya da eksik gördüğünüz bir şey varsa bu iletiyi yanıtlayın - karar
vermeden önce konuşalım.

Kolay gelsin,
Sipario ekibi
