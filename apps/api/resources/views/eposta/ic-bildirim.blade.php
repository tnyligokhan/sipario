<x-eposta.duzen :onizleme="$onizleme" kulak="İç bildirim">

    <x-eposta.baslik>{{ $baslik }}</x-eposta.baslik>

    @if ($aciklama !== '')
        <x-eposta.metin>{{ $aciklama }}</x-eposta.metin>
    @endif

    <x-eposta.veri :satirlar="$satirlar" />

    {{-- İmza YOK, selam YOK: bu postayı okuyan kişi bir işi kuyruğa alacak. Bkz. IcBildirim
         sınıf başlığı. --}}

</x-eposta.duzen>
