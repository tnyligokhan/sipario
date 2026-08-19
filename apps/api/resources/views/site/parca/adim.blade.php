{{-- Kurulum adımları (09-sw-ana.jsx · AdimBlm). Ana sayfa ve Özellikler sayfası ortak kullanır. --}}
<section class="blm kagit2">
    <div class="kap">
        <x-site.blm-bas kulak="Kurulum" baslik="Bugün başlayın, bugün kullanın."
            aciklama="Bilgisayar, kablo, teknik ekip yok. Telefonunuzdaki uygulamayı indirip firma kodunuzla giriyorsunuz." />
        <div class="adim-grid">
            @foreach ($sw['adim'] as $a)
                <div class="adim">
                    <div class="adim-ust">
                        <span class="adim-no">{{ $a['n'] }}</span>
                        <x-site.rozet tur="mor">{{ $a['s'] }}</x-site.rozet>
                    </div>
                    <h3 class="h3">{{ $a['t'] }}</h3>
                    <p class="gvd">{{ $a['a'] }}</p>
                </div>
            @endforeach
        </div>
        <div class="adim-alt">
            <a class="dg dg-b" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="kurulum-adimlari">İşletmenizi açın<x-site.ikon ad="ok" boy="18" kalin="2.2" /></a>
            <span class="kucuk">Müşteri listenizi biz aktarıyoruz — Excel ya da rehber, fark etmez.</span>
        </div>
    </div>
</section>
