{{--
    Ana sayfa · Fiyat özeti (09-sw-ana.jsx · FiyatOzetBlm).

    Fiyatların tamamı PlanDeposu'dan gelir (bkz. site/parca/_kur.php) — sabit yazılmaz.
    Vurgulu karttaki oran rozeti TEMSİLİDİR (_temsili-veri.php · planRozet); null yapılırsa
    rozet basılmaz, kart düzeni bozulmaz.

    KAYNAKTAN AYRILAN TEK CÜMLE: tasarımın "Yıllık … kartla 12 taksite kadar" notu, kartla ödemenin
    henüz AÇIK OLMADIĞI kararıyla çelişiyordu (OKU-BENI çelişki tablosu: iyzico ertelendi). Aynı
    tasarımın fiyat sayfasındaki karşılığı ("havale veya elden · KDV dahil") kullanıldı.
--}}
@php
    $p = $sw['plan']['sipario'];
    $q = $sw['plan']['kurumsal'];
    // Metnin İÇİNDE @if kullanılamaz: Blade yönergeyi yalnız kelime sınırında tanır, "ödemede@if"
    // sessizce ham metin olarak basılır (@endif ise derlenir → sözdizimi hatası). Koşul burada kurulur.
    $yillikAlt = 'yıllık ödemede'.($fiyat['hediyeAy'] > 0 ? ' · '.$fiyat['hediyeAy'].' ay hediye' : '');
@endphp
<section class="blm kagit2">
    <div class="kap">
        <x-site.blm-bas kulak="Fiyat" baslik="Tek plan. Gizli kalem yok."
            aciklama="Kaç müşteriniz olduğuna, kaç sipariş girdiğinize bakmıyoruz. Fiyat aşağıda yazan fiyat." />
        <div class="fo-grid">
            <x-site.pano class="fo fo-vurgu" etiket="En çok seçilen" genis-ic>
                @if (! empty($tmsl['planRozet']))
                    <x-slot:sag>
                        <x-site.rozet tur="mor" nokta>{{ $tmsl['planRozet'] }}</x-site.rozet>
                    </x-slot:sag>
                @endif
                <div class="fo-bas">
                    <span class="h2">{{ $p['ad'] }}</span>
                    <p class="gvd">{{ $p['ozet'] }}</p>
                </div>
                <div class="fo-fiyat">
                    <span class="rakam">{{ $fiyat['yillikAy'] }}</span>
                    <span class="fo-donem">/ ay<br><small>{{ $yillikAlt }}</small></span>
                </div>
                <p class="kucuk fo-not">Aylık ödemede {{ $fiyat['aylik'] }}/ay. Yıllık {{ $fiyat['yillikToplam'] }} · havale veya elden · KDV dahil.</p>
                <ul class="fo-liste">
                    @foreach (array_slice($p['kapsam'], 0, 5) as $x)
                        <li><x-site.ikon ad="onay" boy="16" kalin="2.6" renk="var(--yesil)" />{{ $x['t'] }}</li>
                    @endforeach
                    <li class="fo-daha">+ {{ count($p['kapsam']) - 5 }} özellik daha</li>
                </ul>
                <a class="dg dg-a tam" href="{{ route('subscription.register') }}">{{ $p['cta'] }}</a>
                <span class="kucuk fo-alt">{{ $p['ctaAlt'] }}</span>
            </x-site.pano>

            <x-site.pano class="fo" ince etiket="Çok şubeli" genis-ic>
                <div class="fo-bas">
                    <span class="h2">{{ $q['ad'] }}</span>
                    <p class="gvd">{{ $q['ozet'] }}</p>
                </div>
                <div class="fo-fiyat">
                    <span class="rakam kucuk-rakam">{{ $q['ozelFiyat'] }}</span>
                </div>
                <p class="kucuk fo-not">Şube ve kullanıcı sayısına göre. Kendi sunucunuzda kurulum dahil.</p>
                <ul class="fo-liste">
                    @foreach (array_slice($q['kapsam'], 0, 5) as $x)
                        <li><x-site.ikon ad="onay" boy="16" kalin="2.6" renk="var(--yesil)" />{{ $x['t'] }}</li>
                    @endforeach
                    <li class="fo-daha">+ {{ count($q['kapsam']) - 5 }} özellik daha</li>
                </ul>
                <a class="dg dg-c tam" href="{{ route('site.iletisim') }}">{{ $q['cta'] }}</a>
                <span class="kucuk fo-alt">{{ $q['ctaAlt'] }}</span>
            </x-site.pano>
        </div>
        <div class="fo-link">
            <a class="dg dg-d" href="{{ route('site.fiyatlar') }}">Paketleri karşılaştır<x-site.ikon ad="sag" boy="18" kalin="2.2" /></a>
        </div>
    </div>
</section>
