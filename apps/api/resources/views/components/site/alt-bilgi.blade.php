{{--
    AltBilgi — sayfa altbilgisi. Rota adları henüz açılmamışsa bağlantı atlanır.

    Şirket künyesi (ünvan/adres/MERSİS/VKN) kasıtlı olarak KÖŞELİ PARANTEZ yer tutucudur —
    design_handoff'taki örnek veri ("Sipario Yazılım A.Ş.", uydurma MERSİS no) gerçekmiş gibi
    yayına çıkmasın diye BİLEREK kullanılmadı. Aynı yer tutucu biçimi zaten
    resources/views/legal/docs/mesafeli-satis.blade.php içinde var — gerçek künye netleşince
    (DECISIONS.md) ikisi birden doldurulmalı.
--}}
@php
    $urun = [
        ['Özellikler', 'site.ozellikler'],
        ['Fiyatlandırma', 'site.fiyatlar'],
        ['Kurulum', 'site.ozellikler'],
        ['Sürüm notları', 'site.destek'],
    ];
    $destek = [
        ['Yardım merkezi', 'site.destek'],
        ['Sık sorulanlar', 'site.destek'],
        ['İletişim', 'site.iletisim'],
        ['Demo talebi', 'site.iletisim'],
    ];
    $hesap = [
        ['Giriş yap', 'subscription.login'],
        ['İşletme aç', 'subscription.register'],
        ['Abonelik', 'site.hesap'],
        ['Faturalar', 'site.hesap'],
    ];
    $yasal = [
        ['Mesafeli satış sözleşmesi', 'legal.show', 'mesafeli-satis'],
        ['İptal ve iade', 'legal.show', 'iptal-iade'],
        ['Gizlilik ve KVKK', 'legal.show', 'kvkk-aydinlatma'],
    ];
@endphp
<footer class="alt gece">
    <div class="kap">
        <div class="alt-ust">
            <div class="alt-marka">
                <x-site.marka boy="38" koyu />
                <p class="alt-slogan">Telefon çaldığında müşteriniz ekranda. Bayiler ve esnaf için sipariş, veresiye ve kurye defteri.</p>
                <div class="alt-rzt">
                    <x-site.rozet tur="yesil" nokta>Tüm sistemler çalışıyor</x-site.rozet>
                    <x-site.rozet tur="notr">Veriler Türkiye'de</x-site.rozet>
                </div>
            </div>
            <div class="alt-baglanti">
                <div class="alt-sutun">
                    <span class="mn">Ürün</span>
                    @foreach($urun as [$etiket, $ad])
                        @if(Route::has($ad))<a href="{{ route($ad) }}">{{ $etiket }}</a>@endif
                    @endforeach
                </div>
                <div class="alt-sutun">
                    <span class="mn">Destek</span>
                    @foreach($destek as [$etiket, $ad])
                        @if(Route::has($ad))<a href="{{ route($ad) }}">{{ $etiket }}</a>@endif
                    @endforeach
                </div>
                <div class="alt-sutun">
                    <span class="mn">Hesap</span>
                    @foreach($hesap as [$etiket, $ad])
                        @if(Route::has($ad))<a href="{{ route($ad) }}">{{ $etiket }}</a>@endif
                    @endforeach
                </div>
                <div class="alt-sutun">
                    <span class="mn">Yasal</span>
                    @foreach($yasal as [$etiket, $ad, $doc])
                        @if(Route::has($ad))<a href="{{ route($ad, $doc) }}">{{ $etiket }}</a>@endif
                    @endforeach
                </div>
            </div>
        </div>
        <div class="alt-kunye">
            <div class="alt-k-blok">
                <span class="mn k">Ünvan</span>
                <p>[Şirket unvanı]<br>[açık adres]</p>
            </div>
            <div class="alt-k-blok">
                <span class="mn k">Kayıt</span>
                <p>MERSİS [MERSİS no]<br>[Vergi no / VKN]</p>
            </div>
            <div class="alt-k-blok">
                <span class="mn k">İletişim</span>
                <p><a href="tel:[telefon]">[telefon]</a><br><a href="mailto:[e-posta]">[e-posta]</a></p>
            </div>
            <div class="alt-k-blok">
                <span class="mn k">Ödeme</span>
                <p>Türk Lirası (₺) · Havale / EFT<br>ve elden ödeme</p>
            </div>
        </div>
        <div class="alt-son">
            <span class="kucuk">© {{ date('Y') }} [Şirket unvanı]. Tüm hakları saklıdır.</span>
            <span class="kucuk">Hafta içi 09:00 – 19:00</span>
        </div>
    </div>
</footer>
