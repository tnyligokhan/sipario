<x-eposta.duzen :onizleme="$onizleme" kulak="Ödeme bildirimi">

    <x-eposta.baslik>Ödemenizi bulamadık</x-eposta.baslik>

    {{-- Dil kararı: "reddedildi" YOK. Bkz. OdemeEslesmedi sınıf başlığı — sebep büyük ihtimalle
         bir eksik referans kodudur, bayinin beyanının yanlışlığı değil. --}}
    <x-eposta.metin>
        {{ $isletme }} için {{ $beyanTarihi }} tarihinde bildirdiğiniz ödemeyi banka hesabımızda
        eşleştiremedik. Bu çoğu zaman bir aksaklıktan olur, bir sorun olduğundan değil.
    </x-eposta.metin>

    <x-eposta.veri :satirlar="[
        'Bildirim tarihi' => $beyanTarihi,
        'Bildirilen tutar' => $tutar,
        'Referans' => $referans,
    ]" />

    @if ($not !== '')
        <x-eposta.kutu tur="mor" etiket="Notumuz:">{{ $not }}</x-eposta.kutu>
    @endif

    <x-eposta.metin>
        En sık karşılaştığımız üç sebep:
    </x-eposta.metin>

    <x-eposta.adimlar :adimlar="[
        'Havale açıklamasına referans kodu yazılmamış olabilir — bu durumda ödeme sistemde sizin adınıza bağlanamaz.',
        'Para henüz bankaya düşmemiş olabilir; bazı havaleler bir iş günü sürer.',
        'Tutar bildirdiğinizden farklı gelmiş olabilir (banka masrafı gibi).',
    ]" />

    <x-eposta.metin>
        Ödemeyi yaptıysanız bu iletiyi yanıtlayıp bankanızın işlem numarasını ya da tarih-saat
        bilgisini yazın; hesabımızda arayıp elle eşleştirelim. Henüz ödemediyseniz aşağıdaki
        bağlantıdan güncel bilgilerle yeniden başlayabilirsiniz.
    </x-eposta.metin>

    <x-eposta.dugme :url="$abonelikUrl" tur="c">Ödeme bilgilerini gör</x-eposta.dugme>

    {{-- BRIEF kırmızı çizgi #5'in postadaki karşılığı: hiçbir kapanış postası veriyi tehdit
         olarak kullanmaz. --}}
    <x-eposta.metin :son="true">
        Bu sırada verileriniz olduğu gibi duruyor; hiçbir kaydınız silinmez.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
