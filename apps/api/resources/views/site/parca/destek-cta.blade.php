{{-- Destek · alt çağrı bandı (15-sw-destek.jsx · DestekSayfa alt bloğu). --}}
<section class="blm">
    <div class="kap">
        <x-site.pano class="destek-cta" genis-ic>
            <div class="destek-cta-ic">
                <div>
                    {{-- "Ekran paylaşımıyla birlikte bakabiliriz" cümlesi kaldırıldı: ekran
                         paylaşımı teknik bir kavram ve esnafın çoğu ne olduğunu bilmiyor —
                         üstelik bilmeyen için "benden bir şey yapmam istenecek" korkusu üretir.
                         Vaat aynı kaldı, telefonla anlatılan hâliyle. --}}
                    <h2 class="h2">Cevabı bulamadınız mı?</h2>
                    <p class="gvd">Numaranızı bırakın, biz arayalım. Telefonda birlikte hallederiz.</p>
                </div>
                <a class="dg dg-a dev" href="{{ route('site.iletisim') }}">Bize ulaşın<x-site.ikon ad="ok" boy="19" kalin="2.2" /></a>
            </div>
        </x-site.pano>
    </div>
</section>
