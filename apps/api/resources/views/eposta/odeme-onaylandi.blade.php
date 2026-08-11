<x-eposta.duzen :onizleme="$onizleme" kulak="Ödeme onayı">

    <x-eposta.baslik>Ödemeniz onaylandı</x-eposta.baslik>

    <x-eposta.metin>
        {{ $isletme }} için ödemenizi aldık ve hesabınızı açtık. Uygulamada ve web hesabınızda
        her şey yeniden çalışıyor — beklemenize gerek yok.
    </x-eposta.metin>

    {{-- Kahraman rakam TUTAR DEĞİL, TARİH: bayi parayı zaten ödedi, merak ettiği "ne zamana
         kadar açığım". Tutar aşağıdaki özet tablosunda kayıt olarak duruyor. --}}
    <x-eposta.tutar etiket="Aboneliğiniz şu tarihe kadar geçerli" renk="yesil">{{ $gecerlilikBitisi }}</x-eposta.tutar>

    <x-eposta.veri :satirlar="[
        'İşletme' => $isletme,
        'Dönem' => $donem,
        'Ödenen tutar' => $tutar,
        'Geçerlilik' => $gecerlilikBitisi,
    ]" />

    <x-eposta.metin>
        Süre dolmadan önce size hatırlatma göndereceğiz; takvime not almanıza gerek yok.
    </x-eposta.metin>

    <x-eposta.dugme :url="$hesapUrl">Hesabıma git</x-eposta.dugme>

    <x-eposta.metin :son="true">
        Teşekkür ederiz. Bir sorunuz olursa bu iletiyi yanıtlamanız yeterli.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
