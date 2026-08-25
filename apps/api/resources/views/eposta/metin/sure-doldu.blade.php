@if ($denemeydi)
Deneme süreniz doldu - verileriniz duruyor
==========================================
@else
Aboneliğiniz sona erdi - verileriniz duruyor
============================================
@endif

VERİLERİNİZ DURUYOR. Müşterileriniz, veresiye defteriniz, geçmiş siparişleriniz ve tahsilat
kayıtlarınız sunucuda olduğu gibi saklanıyor. Hiçbir kaydınız silinmedi ve silinmeyecek.

Merhaba {{ $yetkili }}, {{ $isletme }} için {{ $denemeydi ? 'deneme süreniz' : 'aboneliğiniz' }}
{{ $bitisTarihi }} tarihinde doldu. Bu tarihten itibaren uygulamaya yeni kayıt girilemiyor.

NE DURDU: yeni sipariş, tahsilat, müşteri ve masraf kaydı girilemiyor.

NE DURMADI: telefonlarınızda henüz gönderilmemiş kayıtlar varsa onlar sunucuya akmaya devam
ediyor - kilitten hemen önce girilen siparişler kaybolmaz. Geçmiş kayıtlarınızı görüntülemeye
de devam edebilirsiniz.

NASIL GERİ GELİR: ödemeniz bize ulaştığı an hesabınız açılır ve her şey bıraktığınız yerden
devam eder. Yeniden kurulum ya da veri girişi gerekmez.

Aboneliği başlatın: {{ $abonelikUrl }}

Devam etmemeye karar verirseniz de verileriniz sizindir: bu iletiyi yanıtlayıp dışa aktarım
isteyin, kayıtlarınızı size gönderelim.

Kolay gelsin,
Sipario ekibi
