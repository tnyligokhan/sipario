{{--
    Son çağrı bandı (09-sw-ana.jsx · SonCagri). Ana sayfa, Özellikler ve Fiyatlandırma ortak kullanır.
    Deneme süresi PlanDeposu'dan gelir — tasarımdaki "14 gün" sunucunun verdiği süre değildi.
--}}
<section class="son gece">
    <div class="kap son-ic">
        <div>
            <h2 class="h1">Bu akşam kasayı<br>Sipario ile kapatın.</h2>
            <p class="gvd b son-alt">{{ $fiyat['deneme'] }} gün ücretsiz. Kart bilgisi yok, taahhüt yok. Beğenmezseniz verinizi Excel olarak alıp gidersiniz.</p>
        </div>
        <div class="son-dg">
            <a class="dg dg-a dev" href="{{ route('subscription.register') }}">İşletmenizi açın<x-site.ikon ad="ok" boy="19" kalin="2.2" /></a>
            <a class="dg dg-c dev" href="{{ route('site.iletisim') }}">Önce konuşalım</a>
        </div>
    </div>
</section>
