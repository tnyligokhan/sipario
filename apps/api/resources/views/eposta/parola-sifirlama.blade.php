<x-eposta.duzen :onizleme="$onizleme" kulak="Parola sıfırlama">

    <x-eposta.baslik>Parolanızı sıfırlayın</x-eposta.baslik>

    <x-eposta.metin>
        Merhaba {{ $yetkili }}, Sipario hesabınız için parola sıfırlama isteği aldık. Yeni
        parolanızı belirlemek için aşağıdaki düğmeye basın.
    </x-eposta.metin>

    <x-eposta.dugme :url="$url">Yeni parola belirle</x-eposta.dugme>

    <x-eposta.kutu tur="sari" etiket="Bağlantı {{ $gecerlilikDakika }} dakika geçerli.">
        Süre dolduysa parola sayfasından yeniden istek gönderebilirsiniz.
    </x-eposta.kutu>

    {{-- Eylemsizliğin güvenli olduğunu söylemek ŞART: postayı isteyen kişi ile alan kişi aynı
         olmayabilir. Bkz. ParolaSifirlama sınıf başlığı. --}}
    <x-eposta.metin>
        Bu isteği siz göndermediyseniz yapmanız gereken bir şey yok — bu iletiyi yok sayın.
        Bağlantı kullanılmadığı sürece parolanız değişmez.
    </x-eposta.metin>

    <x-eposta.metin>
        Düğme çalışmazsa bu adresi tarayıcınıza yapıştırın:
    </x-eposta.metin>

    {{-- Ham adres: kurumsal posta istemcilerinin bir bölümü düğmedeki bağlantıyı tarama
         hizmetine sarar ya da düşürür; o hâlde kullanıcının elinde kalan tek şey budur. --}}
    <x-eposta.metin :son="true">
        <span style="word-break:break-all;font-family:'JetBrains Mono',ui-monospace,SFMono-Regular,Consolas,monospace;font-size:12.5px;color:#7B7486;">{{ $url }}</span>
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
