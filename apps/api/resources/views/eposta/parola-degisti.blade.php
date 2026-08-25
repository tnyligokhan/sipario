<x-eposta.duzen :onizleme="$onizleme" kulak="Güvenlik">

    <x-eposta.baslik>Parolanız değiştirildi</x-eposta.baslik>

    <x-eposta.metin>
        Merhaba {{ $yetkili }}, Sipario hesabınızın parolası az önce değiştirildi. Bu değişikliği
        siz yaptıysanız yapmanız gereken bir şey yok.
    </x-eposta.metin>

    <x-eposta.veri :satirlar="['Değişiklik zamanı' => $zaman]" />

    {{-- Düğme BİLEREK yok — bkz. ParolaDegisti sınıf başlığı: "değiştirmediyseniz tıklayın"
         kalıbı kimlik avının taklit ettiği kalıptır. Tek çağrı bilinen kanaldan yanıt. --}}
    <x-eposta.kutu tur="kirmizi" etiket="Bu değişikliği siz yapmadıysanız:">
        hesabınıza başkası erişmiş olabilir. Bu iletiyi hemen yanıtlayın ya da destek
        hattımızdan bize ulaşın; hesabınızı birlikte kapatalım.
    </x-eposta.kutu>

    <x-eposta.metin :son="true">
        Güvenliğiniz için bu iletide hiçbir bağlantı ya da düğme yok. Sipario size hiçbir zaman
        parolanızı e-postayla sormaz.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
