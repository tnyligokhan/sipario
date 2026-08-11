{{ $kuryeAdi }} için kurye hesabı açıldı
========================================

{{ $isletme }} ekibine yeni bir kurye hesabı eklendi. Kuryenizin uygulamaya girmek için ihtiyacı
olan bilgiler aşağıda.

Ad soyad      : {{ $kuryeAdi }}
Firma kodu    : {{ $firmaKodu }}
Kullanıcı adı : {{ $kullaniciAdi }}

PAROLA BU İLETİDE YOK. Kuryenizin parolası, hesabı açarken sizin belirlediğiniz paroladır.
Güvenlik gereği parolaları e-postayla göndermiyoruz; kuryenize kendiniz iletin.

Kuryeniz uygulamayı telefonuna kurup bu üç bilgiyle girer: firma kodu, kullanıcı adı, parola.
E-posta adresiyle giriş yapılmaz.
@if ($kalanHak > 0)

Paketinizde {{ $kalanHak }} kurye hakkı daha var.
@else

KURYE HAKKINIZ DOLDU. Yeni bir kurye eklemek isterseniz bu iletiyi yanıtlayın, ek kurye
paketini birlikte açalım.
@endif

Ekibi yönetin: {{ $hesapUrl }}

Bu hesabı siz açmadıysanız hemen bize yazın.

Kolay gelsin,
Sipario ekibi
