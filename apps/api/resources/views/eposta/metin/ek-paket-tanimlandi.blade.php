{{ $paketAdi }} hesabınıza tanımlandı
=====================================

@if ($bedelsiz)
{{ $isletme }} hesabınıza ücretsiz olarak ek hak tanımladık. Hemen kullanabilirsiniz.
@else
{{ $isletme }} hesabınıza satın aldığınız ek paket tanımlandı. Hemen kullanabilirsiniz.
@endif

EKLENEN HAK: +{{ $adet }}

İşletme    : {{ $isletme }}
Paket      : {{ $paketAdi }}
Tür        : {{ $turAdi }}
Adet       : {{ $adet }}
Tutar      : {{ $bedelsiz ? 'Ücretsiz' : $tutar }}
Tanımlama  : {{ $tanimlamaTarihi }}

@if ($turAdi === 'Kurye hakkı')
Yeni kurye hesaplarını web hesabınızdaki "Ekip" bölümünden açabilirsiniz.
@else
Kontörleriniz rota planlamada otomatik olarak kullanılır; ayrıca bir işlem yapmanıza gerek yok.
@endif

Hesabınız: {{ $hesapUrl }}

Bu tanımlamayla ilgili bir yanlışlık olduğunu düşünüyorsanız bu iletiyi yanıtlayın.

Kolay gelsin,
Sipario ekibi
