{{ $kuryeAdi }} için {{ mb_strtolower($rolAdi) }} hesabı açıldı
========================================

{{ $isletme }} ekibine yeni bir personel hesabı eklendi ({{ $rolAdi }}). Personelinizin
uygulamaya girmek için ihtiyacı olan bilgiler aşağıda.

Ad soyad      : {{ $kuryeAdi }}
Görevi        : {{ $rolAdi }}
Firma kodu    : {{ $firmaKodu }}
Kullanıcı adı : {{ $kullaniciAdi }}

PAROLA BU İLETİDE YOK. Personelinizin parolası, hesabı açarken sizin belirlediğiniz paroladır.
Güvenlik gereği parolaları e-postayla göndermiyoruz; kendisine siz iletin.

Personeliniz uygulamayı telefonuna kurup bu üç bilgiyle girer: firma kodu, kullanıcı adı, parola.
E-posta adresiyle giriş yapılmaz.
@if ($kalanHak > 0)

Paketinizde {{ $kalanHak }} personel hakkı daha var.
@else

PERSONEL HAKKINIZ DOLDU. Yeni bir hesap eklemek isterseniz bu iletiyi yanıtlayın, ek kurye
paketini birlikte açalım.
@endif

Ekibi yönetin: {{ $hesapUrl }}

Bu hesabı siz açmadıysanız hemen bize yazın.

Kolay gelsin,
Sipario ekibi
