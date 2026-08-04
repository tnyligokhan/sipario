{{--
    Ödeme yöntemi — tasarım HOdeme. "Kart ile ödeme · Yakında" metni birebir.

    REFERANS KODU: tasarım `SIP-{FİRMAKODU}` diye sabit bir kod gösteriyordu; bizde kod ödeme
    başlatılırken üretilir (OdemeBildirimServisi::referansUret — sonundaki rastgele parça aynı
    bayinin iki bildirimini ayırır). Burada BEKLEYEN bildirimin gerçek kodu gösterilir; bekleyen
    yoksa kodun ne zaman üretileceği söylenir. Var olmayan bir kodu göstermek, bayinin havale
    açıklamasına eşleşmeyecek bir metin yazmasına yol açardı.
--}}
@php $bekleyen = $this->bekleyenBildirim(); $sirket = $this->sirket(); @endphp

<div class="hb">
    <x-site.pano etiket="Havale / EFT">
        <x-slot:sag><x-site.rozet tur="yesil" :nokta="true">Kullanımda</x-site.rozet></x-slot:sag>
        <p class="gvd">
            @if ($deneme)
                Aboneliği başlattığınızda ödemeyi banka havalesiyle alabilirsiniz. Dekont ulaştığı gün hesabınız açılır.
            @else
                Yenileme tarihinden önce aşağıdaki hesaba ödeme yapın. Açıklama alanına referans kodunuzu yazın; dekont ulaştığı gün dönem uzatılır.
            @endif
        </p>
        <hr class="ayrac">
        <div class="ab-satirlar">
            <div class="ozet-r"><span>Alıcı ünvanı</span><b>{{ $sirket['unvan'] }}</b></div>
            <div class="ozet-r"><span>Banka</span><b>{{ $sirket['banka'] }}</b></div>
            <div class="ozet-r"><span>IBAN</span><b class="tab">{{ $sirket['iban'] }}</b></div>
            <div class="ozet-r">
                <span>Referans kodu</span>
                <b class="tab">{{ $bekleyen?->reference_code ?? 'Ödemeyi başlattığınızda üretilir' }}</b>
            </div>
        </div>
        <div class="dg-grup" style="margin-top:20px"
            x-data="kopyalaKutusu(@js('Alıcı ünvanı: '.$sirket['unvan'].' | Banka: '.$sirket['banka'].' | IBAN: '.$sirket['iban']))">
            <button type="button" class="dg dg-c" @click="kopyala('Hesap bilgileri kopyalandı')">
                <x-site.ikon ad="kopyala" boy="17" kalin="2.1" />Bilgileri kopyala
            </button>
            <a class="dg dg-d" href="{{ $this->odemeUrl() }}">
                <x-site.ikon ad="ok" boy="17" kalin="2.1" />Ödeme ekranına git
            </a>
        </div>
    </x-site.pano>

    <x-site.pano etiket="Elden ödeme">
        <x-slot:sag><x-site.rozet tur="yesil" :nokta="true">Kullanımda</x-site.rozet></x-slot:sag>
        <p class="gvd">Ankara, Antalya ve İzmir'de ödemeyi elden alıyoruz. Talebinizi bırakın, aynı gün arayarak saat ayarlayalım; makbuzunuz teslimde verilir.</p>
        <a class="dg dg-c" style="margin-top:18px" href="{{ $this->odemeUrl() }}">
            <x-site.ikon ad="telefon" boy="17" kalin="2.1" />Elden ödeme talebi bırak
        </a>
    </x-site.pano>

    <x-site.pano :ince="true" etiket="Kart ile ödeme">
        <x-slot:sag><x-site.rozet tur="notr">Yakında</x-site.rozet></x-slot:sag>
        <div class="hb-bos">
            <span class="hb-bos-ik"><x-site.ikon ad="kart" boy="22" kalin="1.9" renk="var(--sonuk)" /></span>
            <b class="h4">Kartla ödeme henüz açık değil</b>
            <p class="kucuk">Kredi ve banka kartıyla online ödeme üzerinde çalışıyoruz. Açıldığında kartınızı buradan kaydedip otomatik yenilemeye geçebileceksiniz.</p>
        </div>
    </x-site.pano>
</div>
