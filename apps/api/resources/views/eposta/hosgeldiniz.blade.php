<x-eposta.duzen :onizleme="$onizleme" kulak="Hoş geldiniz">

    <x-eposta.baslik>{{ $isletme }} için hesabınız hazır</x-eposta.baslik>

    <x-eposta.metin>
        Merhaba {{ $yetkili }}, Sipario hesabınızı açtık. {{ $denemeGun }} günlük deneme süreniz
        başladı ve bugünden itibaren her şey açık — sipariş, veresiye defteri, kurye takibi.
    </x-eposta.metin>

    {{-- Postanın en büyük öğesi BU. Mobil giriş firma kodu + kullanıcı adı ister, e-posta kabul
         etmez; bayi kayıt ekranını kapattıysa kodu başka hiçbir yerden öğrenemez. --}}
    <x-eposta.kod etiket="Firma kodunuz">{{ $firmaKodu }}</x-eposta.kod>

    <x-eposta.metin>
        Uygulamaya bu kod ve <strong>{{ $kullaniciAdi }}</strong> kullanıcı adıyla girersiniz.
        Parolanız kayıt sırasında belirlediğiniz paroladır — güvenlik gereği bu iletide yazmıyoruz.
    </x-eposta.metin>

    <x-eposta.adimlar :adimlar="[
        'Sipario uygulamasını telefonunuza kurun.',
        'Firma kodu, kullanıcı adı ve parolanızla girin.',
        'Sattığınız ürünleri ve fiyatlarını girin — bir kereye mahsus.',
        'Müşteri listenizi ekleyin; telefon çaldığında ekranda kim aradığı çıksın.',
    ]" />

    <x-eposta.kutu tur="mor" etiket="Arayan tanıma için:">
        Uygulamayı telefonun pil ayarlarında “kısıtlama yok” olarak işaretleyin. Xiaomi, Redmi ve
        Poco cihazlarda bu adım atlanırsa telefon uygulamayı arka planda kapatır ve gelen aramada
        müşteri adı ekrana gelmez.
    </x-eposta.kutu>

    <x-eposta.veri :satirlar="[
        'İşletme' => $isletme,
        'Firma kodu' => $firmaKodu,
        'Kullanıcı adı' => $kullaniciAdi,
        'Deneme bitişi' => $denemeBitisi,
    ]" />

    <x-eposta.dugme :url="$hesapUrl">Hesabıma git</x-eposta.dugme>

    <x-eposta.metin :son="true">
        Kurulumda takılırsanız bu iletiyi yanıtlayın, yardımcı olalım.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
