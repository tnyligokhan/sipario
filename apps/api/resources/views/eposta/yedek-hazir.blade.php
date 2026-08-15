<x-eposta.duzen :onizleme="$onizleme" kulak="İç bildirim">

    <x-eposta.baslik>Günlük veritabanı yedeği</x-eposta.baslik>

    @if ($bayat)
        <x-eposta.kutu tur="sari" etiket="Dikkat">{{ $bayatUyarisi }}</x-eposta.kutu>
    @endif

    <x-eposta.veri :satirlar="$satirlar" />

    <x-eposta.dugme :url="$indirmeUrl">Yedeği indir</x-eposta.dugme>

    {{-- Bağlantı panel girişinin ardındadır: oturum yoksa önce giriş ekranı gelir, sonra
         indirme başlar. Bu bilerek böyledir — dosya ürünün en yoğun kişisel veri
         taşıyıcısıdır ve "bağlantıyı bilen indirir" deseni onu e-posta kutusu kadar
         güvenli yapardı. --}}
    <x-eposta.metin>
        Bağlantı panel girişinin arkasındadır; oturumun kapalıysa önce giriş ekranı gelir.
        Bağlantının son kullanma tarihi yoktur, ama dosya saklama süresi dolunca sunucudan
        silinir (7 günlük · 4 haftalık · 6 aylık).
    </x-eposta.metin>

    <x-eposta.kod etiket="Geri yükleme">{{ $geriYuklemeKomutu }}</x-eposta.kod>

    <x-eposta.metin>
        Geri yükleme mevcut veriyi SİLER ve dosyadakiyle değiştirir. Boş bir veritabanında
        deneyip sonucu görmeden canlıda çalıştırma.
    </x-eposta.metin>

    {{-- İmza YOK, selam YOK: iç bildirim. Bkz. IcBildirim sınıf başlığı. --}}

</x-eposta.duzen>
