Günlük veritabanı yedeği
=======================
@if ($bayat)

DİKKAT: {{ $bayatUyarisi }}
@endif

@foreach ($satirlar as $etiket => $deger)
{{ $etiket }}: {{ $deger }}
@endforeach

İndirme bağlantısı (panel girişi gerekir):
{{ $indirmeUrl }}

Bağlantının son kullanma tarihi yoktur, ama dosya saklama süresi dolunca sunucudan
silinir (7 günlük, 4 haftalık, 6 aylık).

Geri yükleme:
{{ $geriYuklemeKomutu }}

Geri yükleme mevcut veriyi SİLER ve dosyadakiyle değiştirir. Boş bir veritabanında
deneyip sonucu görmeden canlıda çalıştırma.
