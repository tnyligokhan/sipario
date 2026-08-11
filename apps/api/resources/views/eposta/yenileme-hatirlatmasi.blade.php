<x-eposta.duzen :onizleme="$onizleme" kulak="Abonelik yenileme">

    <x-eposta.baslik>Aboneliğinizin yenilenme vakti geldi</x-eposta.baslik>

    {{-- Önce teşekkür: bu bayi bir yıldır ödeyen müşteri, aday değil. Bkz. sınıf başlığı. --}}
    <x-eposta.metin>
        Merhaba {{ $yetkili }}, {{ $isletme }} ile geçen yıl bizimle çalıştığınız için teşekkür
        ederiz. Aboneliğiniz <strong>{{ $bitisTarihi }}</strong> tarihinde doluyor.
    </x-eposta.metin>

    <x-eposta.tutar etiket="Yenilemeye kalan süre" :renk="$kalanGun <= 3 ? 'kirmizi' : 'murekkep'">{{ $kalanGun }} gün</x-eposta.tutar>

    @if ($yillikTutar !== '')
        <x-eposta.veri :satirlar="[
            'İşletme' => $isletme,
            'Mevcut abonelik bitişi' => $bitisTarihi,
            'Yenileme tutarı' => $yillikTutar,
        ]" />
    @else
        <x-eposta.veri :satirlar="[
            'İşletme' => $isletme,
            'Mevcut abonelik bitişi' => $bitisTarihi,
        ]" />
    @endif

    {{-- Otomatik tahsilat YOK — bunu söylemek şart: bayi "nasılsa çekilir" diye bekler ve
         süresi dolar. Bkz. sınıf başlığı. --}}
    <x-eposta.kutu tur="sari" etiket="Ödeme otomatik alınmaz.">
        Kartınızdan bir çekim yapılmaz; yenileme için havale/EFT yapmanız ya da bizi arayıp
        elden ödeme için sözleşmeniz gerekir. Süre dolmadan öderseniz hiçbir kesinti yaşamazsınız.
    </x-eposta.kutu>

    <x-eposta.dugme :url="$abonelikUrl">Aboneliği yenile</x-eposta.dugme>

    <x-eposta.metin :son="true">
        Bu yıl için paketinizi değiştirmek ya da ek kurye hakkı eklemek isterseniz bu iletiyi
        yanıtlayın, birlikte ayarlayalım.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
