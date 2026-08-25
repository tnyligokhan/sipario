<x-eposta.duzen :onizleme="$onizleme" kulak="Ekip">

    <x-eposta.baslik>{{ $kuryeAdi }} için hesap açıldı</x-eposta.baslik>

    <x-eposta.metin>
        {{ $isletme }} ekibine yeni bir personel hesabı eklendi. Personelinizin uygulamaya
        girmek için ihtiyacı olan bilgiler aşağıda.
    </x-eposta.metin>

    <x-eposta.veri :satirlar="[
        'Ad soyad' => $kuryeAdi,
        'Görevi' => $rolAdi,
        'Firma kodu' => $firmaKodu,
        'Kullanıcı adı' => $kullaniciAdi,
    ]" />

    {{-- Parola BİLEREK yok — bkz. KuryeHesabiAcildi sınıf başlığı. --}}
    <x-eposta.kutu tur="mor" etiket="Parola bu iletide yok.">
        Personelinizin parolası, hesabı açarken sizin belirlediğiniz paroladır. Güvenlik gereği
        parolaları e-postayla göndermiyoruz; kendisine siz iletin.
    </x-eposta.kutu>

    <x-eposta.metin>
        Personeliniz uygulamayı telefonuna kurup bu üç bilgiyle girer: firma kodu, kullanıcı adı,
        parola. E-posta adresiyle giriş yapılmaz.
    </x-eposta.metin>

    @if ($kalanHak > 0)
        <x-eposta.metin>
            Paketinizde <strong>{{ $kalanHak }} personel hakkı</strong> daha var.
        </x-eposta.metin>
    @else
        <x-eposta.kutu tur="sari" etiket="Personel hakkınız doldu.">
            Yeni bir hesap eklemek isterseniz bu iletiyi yanıtlayın, ek kurye paketini
            birlikte açalım.
        </x-eposta.kutu>
    @endif

    <x-eposta.dugme :url="$hesapUrl" tur="c">Ekibi yönet</x-eposta.dugme>

    <x-eposta.metin :son="true">
        Bu hesabı siz açmadıysanız hemen bize yazın.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
