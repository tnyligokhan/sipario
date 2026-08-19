{{--
    Ana sayfa · Hero (09-sw-ana.jsx · HeroBlm). Koyu zemin; sağda gerçek ölçekli mobil maket.

    Kaynaktaki <TelefonCanli> üç kareyi (bekleme → çağrı → sipariş oluştu) döngüye alıyordu. Burada
    maket SUNUCUDA basılan statik HTML'dir; döngü için maketin üç ayrı kopyasını sayfaya gömüp
    Alpine ile değiştirmek gerekirdi (~60 KB fazladan işaretleme). Bunun yerine anlatının doruk
    karesi — GELEN ÇAĞRI kartı — sabit gösteriliyor; başlığın söylediği şeyin ta kendisi.
--}}
<section class="hero gece">
    <div class="hero-isik"></div>
    <div class="kap hero-ic">
        <div class="hero-sol">
            <span class="blm-kulak mn"><i></i>Bayiler · esnaf · yerel teslimat</span>
            <h1 class="h-dev">Telefon çaldığında<br>müşteriniz<br><em>ekranda.</em></h1>
            <p class="gvd b hero-alt">Sipario, gelen numarayı müşteri defterinizle eşleştirir: kim aradı, nerede oturuyor, ne kadar borcu var, en son ne almıştı — daha “alo” demeden ekranda.</p>
            <div class="dg-grup hero-dg">
                <a class="dg dg-a dev" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="hero">{{ $fiyat['deneme'] }} gün ücretsiz dene<x-site.ikon ad="ok" boy="19" kalin="2.2" /></a>
                <a class="dg dg-c dev" href="{{ route('site.ozellikler') }}">Nasıl çalıştığını gör</a>
            </div>
            <ul class="hero-guvence">
                @foreach (['Kart bilgisi istemiyoruz', 'Kurulum 10 dakika', 'Müşteri aktarımı bizden'] as $g)
                    <li><x-site.ikon ad="onay" boy="16" kalin="2.6" renk="#4FD69C" />{{ $g }}</li>
                @endforeach
            </ul>
        </div>
        {{--
            Kendi kendine oynayan gösterim (kaynak: 07-sw-telefon.jsx · TelefonCanli). React'te tek
            maket prop değiştirerek yeniden render ediliyordu; burada üç kare önceden basılıp `x-show`
            ile değiştiriliyor — ana-tur bölümündeki sekmeli maketlerle aynı desen, ilk kare
            x-cloak'suz ki Alpine yüklenmeden de sakin ekran görünsün (JS yoksa donuk ama DOĞRU kare).
            Zamanlayıcı public/js/alpine.js · `heroDongu` içinde (csp_safe: setTimeout HTML'de yasak).
        --}}
        <div class="hero-sag" x-data="heroDongu">
            <div x-show="kare === 0"><x-site.telefon ekran="ana" :oran="0.72" /></div>
            <div x-show="kare === 1" x-cloak><x-site.telefon ekran="ana" :oran="0.72" cagri /></div>
            <div x-show="kare === 2" x-cloak>
                <x-site.telefon ekran="ana" :oran="0.72" bildirim="Sipariş #1043 oluşturuldu" ciro="12.570" :acik="8" />
            </div>
        </div>
    </div>
    <div class="hero-serit">
        <div class="kap hero-serit-ic">
            <span class="mn">Her gün kullanan işletmeler</span>
            <div class="hero-sektor">
                @foreach ($sw['sektor'] as $s)
                    <span>{{ $s }}</span>
                @endforeach
            </div>
        </div>
    </div>
</section>
