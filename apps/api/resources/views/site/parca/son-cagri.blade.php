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
            <h2 class="h1">Bu akşamki kasayı<br>Sipario ile kapatın.</h2>
            <p class="gvd b son-alt">{{ $fiyat['deneme'] }} gün ücretsiz, kart bilgisi istemiyoruz, taahhüt yok. Beğenmezseniz bir şey yapmanız bile gerekmiyor — istediğinizde verilerinizi Excel olarak gönderiyoruz.</p>
        </div>
        <div class="son-dg">
            <a class="dg dg-a dev" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="son-cagri">İşletmenizi açın<x-site.ikon ad="ok" boy="19" kalin="2.2" /></a>
            <a class="dg dg-c dev" href="{{ route('site.iletisim') }}">Önce bir konuşalım</a>
        </div>
    </div>
</section>
