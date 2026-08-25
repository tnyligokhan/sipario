<x-eposta.duzen :onizleme="$onizleme" kulak="Ek paket">

    <x-eposta.baslik>{{ $paketAdi }} tanımlandı</x-eposta.baslik>

    <x-eposta.metin>
        @if ($bedelsiz)
            {{ $isletme }} hesabınıza ücretsiz olarak ek hak tanımladık. Hemen kullanabilirsiniz.
        @else
            {{ $isletme }} hesabınıza satın aldığınız ek paket tanımlandı. Hemen kullanabilirsiniz.
        @endif
    </x-eposta.metin>

    <x-eposta.tutar etiket="Eklenen hak" renk="mor">+{{ $adet }}</x-eposta.tutar>

    <x-eposta.veri :satirlar="[
        'İşletme' => $isletme,
        'Paket' => $paketAdi,
        'Tür' => $turAdi,
        'Adet' => (string) $adet,
        'Tutar' => $bedelsiz ? 'Ücretsiz' : $tutar,
        'Tanımlama' => $tanimlamaTarihi,
    ]" />

    <x-eposta.metin>
        @if ($turAdi === 'Kurye hakkı')
            Yeni kurye hesaplarını web hesabınızdaki <strong>Ekip</strong> bölümünden
            açabilirsiniz.
        @else
            Kontörleriniz rota planlamada otomatik olarak kullanılır; ayrıca bir işlem
            yapmanıza gerek yok.
        @endif
    </x-eposta.metin>

    <x-eposta.dugme :url="$hesapUrl" tur="c">Hesabıma git</x-eposta.dugme>

    <x-eposta.metin :son="true">
        Bu tanımlamayla ilgili bir yanlışlık olduğunu düşünüyorsanız bu iletiyi yanıtlayın.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
