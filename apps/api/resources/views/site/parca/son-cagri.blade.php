{{--
    Son çağrı bandı (09-sw-ana.jsx · SonCagri). Ana sayfa, Özellikler ve Fiyatlandırma ortak kullanır.
    Deneme süresi PlanDeposu'dan gelir — tasarımdaki "14 gün" sunucunun verdiği süre değildi.
--}}
<section class="son gece">
    <div class="kap son-ic">
        <div>
            {{--
                "Beğenmezseniz verinizi Excel olarak alıp gidersiniz" cümlesi DEĞİŞTİ
                (2026-08-19): dışa aktarım uygulamada bir düğme değil, destek kanalından
                yürüyen bir taleptir (BRIEF: "uygulamada buton yok"). Cümle, olmayan bir
                düğmeyi tarif ediyordu — vaat doğruydu, yolu yanlıştı.
            --}}
            {{-- Cümle kısaldı (2026-08-19): "30 gün ücretsiz / kart istemiyoruz" ikilisi ana
                 sayfada zaten üç kez geçiyor (hero güvence listesi, fiyat kartı, SSS). Dördüncü
                 tekrar okunmuyor, yalnız bandı ağırlaştırıyordu. Burada kalan tek yeni bilgi
                 ayrılırken verinin ne olacağı — o duruyor. --}}
            <h2 class="h1">Bu akşamki kasayı<br>Sipario ile kapatın.</h2>
            <p class="gvd b son-alt">{{ $fiyat['deneme'] }} gün ücretsiz. Beğenmezseniz bırakın — defterinizi Excel olarak size gönderiyoruz.</p>
        </div>
        <div class="son-dg">
            <a class="dg dg-a dev" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="son-cagri">İşletmenizi açın<x-site.ikon ad="ok" boy="19" kalin="2.2" /></a>
            <a class="dg dg-c dev" href="{{ route('site.iletisim') }}">Önce bir konuşalım</a>
        </div>
    </div>
</section>
