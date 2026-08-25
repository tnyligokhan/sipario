<x-eposta.duzen :onizleme="$onizleme" kulak="Abonelik durumu">

    <x-eposta.baslik>
        @if ($denemeydi)
            Deneme süreniz doldu
        @else
            Aboneliğiniz sona erdi
        @endif
    </x-eposta.baslik>

    {{-- İLK CÜMLE VERİ GÜVENCESİ. Bkz. SureDoldu sınıf başlığı: bayinin bu postayı okuduğu an
         aklındaki soru "param" değil "defterim". Ödeme çağrısı postanın ALTINDA. --}}
    <x-eposta.kutu tur="yesil" etiket="Verileriniz duruyor.">
        Müşterileriniz, veresiye defteriniz, geçmiş siparişleriniz ve tahsilat kayıtlarınız
        sunucuda olduğu gibi saklanıyor. Hiçbir kaydınız silinmedi ve silinmeyecek.
    </x-eposta.kutu>

    <x-eposta.metin>
        Merhaba {{ $yetkili }}, {{ $isletme }} için
        {{ $denemeydi ? 'deneme süreniz' : 'aboneliğiniz' }} {{ $bitisTarihi }} tarihinde doldu.
        Bu tarihten itibaren uygulamaya yeni kayıt girilemiyor.
    </x-eposta.metin>

    <x-eposta.veri :satirlar="[
        'İşletme' => $isletme,
        ($denemeydi ? 'Deneme bitişi' : 'Abonelik bitişi') => $bitisTarihi,
        'Durum' => 'Kayıt girişi kapalı',
    ]" />

    <x-eposta.metin>
        <strong>Ne durdu:</strong> yeni sipariş, tahsilat, müşteri ve masraf kaydı girilemiyor.
    </x-eposta.metin>

    {{-- Bu madde teknik bir ayrıntı gibi görünür ama saha için kritiktir: kurye kilit anında
         telefonunda bekleyen teslimleri kaybettiğini sanırsa gün sonu kasası tutmaz ve ürüne
         güven ölür (BRIEF: "rakamlar defterle tutmazsa ürüne güven ölür"). --}}
    <x-eposta.metin>
        <strong>Ne durmadı:</strong> telefonlarınızda henüz gönderilmemiş kayıtlar varsa onlar
        sunucuya akmaya devam ediyor — kilitten hemen önce girilen siparişler kaybolmaz.
        Geçmiş kayıtlarınızı görüntülemeye de devam edebilirsiniz.
    </x-eposta.metin>

    <x-eposta.metin>
        <strong>Nasıl geri gelir:</strong> ödemeniz bize ulaştığı an hesabınız açılır ve her şey
        bıraktığınız yerden devam eder. Yeniden kurulum ya da veri girişi gerekmez.
    </x-eposta.metin>

    <x-eposta.dugme :url="$abonelikUrl">Aboneliği başlat</x-eposta.dugme>

    {{-- BRIEF: "bayi destek kanalı üzerinden her zaman verisinin dışa aktarımını talep
         edebilir; bu kapı kapalı kalamaz." Kapıyı burada AÇIKÇA gösteriyoruz — abonelik
         bitmişken bile. --}}
    <x-eposta.metin :son="true">
        Devam etmemeye karar verirseniz de verileriniz sizindir: bu iletiyi yanıtlayıp dışa
        aktarım isteyin, kayıtlarınızı size gönderelim.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
