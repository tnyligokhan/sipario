<x-eposta.duzen :onizleme="$onizleme" kulak="Deneme süresi">

    <x-eposta.baslik>
        @if ($kalanGun <= 1)
            Deneme süreniz yarın bitiyor
        @else
            Deneme sürenizin bitmesine {{ $kalanGun }} gün kaldı
        @endif
    </x-eposta.baslik>

    <x-eposta.metin>
        Merhaba {{ $yetkili }}, {{ $isletme }} için açtığınız deneme süresi
        <strong>{{ $bitisTarihi }}</strong> tarihinde doluyor.
    </x-eposta.metin>

    <x-eposta.tutar etiket="Kalan süre" :renk="$kalanGun <= 3 ? 'kirmizi' : 'murekkep'">{{ $kalanGun }} gün</x-eposta.tutar>

    {{-- SÜRE DOLUNCA NE OLUR, AÇIKÇA. Bunu yazmamak bayiyi "her şeyi kaybedecek miyim" korkusuyla
         baş başa bırakır; BRIEF kırmızı çizgi #5 tam tersini garanti eder ve o garanti ancak
         SÖYLENİRSE bir değer taşır. --}}
    <x-eposta.kutu tur="mor" etiket="Süre dolunca ne olur:">
        Yeni sipariş, tahsilat ve müşteri kaydı girilemez. Buraya kadar girdiğiniz hiçbir şey
        silinmez — müşterileriniz, veresiye defteriniz ve geçmiş siparişleriniz sunucuda durur
        ve abonelik başladığı an olduğu gibi geri gelir.
    </x-eposta.kutu>

    @if ($yillikTutar !== '')
        <x-eposta.veri :satirlar="[
            'İşletme' => $isletme,
            'Deneme bitişi' => $bitisTarihi,
            'Yıllık abonelik' => $yillikTutar,
        ]" />
    @else
        <x-eposta.veri :satirlar="[
            'İşletme' => $isletme,
            'Deneme bitişi' => $bitisTarihi,
        ]" />
    @endif

    <x-eposta.dugme :url="$abonelikUrl">Aboneliği başlat</x-eposta.dugme>

    <x-eposta.metin>
        Havale/EFT ile ödeyebilir ya da bizi arayıp elden ödeme için sözleşebilirsiniz.
    </x-eposta.metin>

    <x-eposta.metin :son="true">
        Ürünle ilgili bir sorunuz ya da eksik gördüğünüz bir şey varsa bu iletiyi yanıtlayın —
        karar vermeden önce konuşalım.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
