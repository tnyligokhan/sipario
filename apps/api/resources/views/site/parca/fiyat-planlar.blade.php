{{--
    Fiyatlandırma · hero + dönem anahtarı + iki plan kartı (11-sw-fiyat.jsx · FiyatSayfa üst bloğu,
    DonemAnahtar, PlanKart).

    Dönem anahtarı Alpine ile. Sunucu YILLIK dönemi basar (tasarımın açılış durumu); JavaScript
    kapalıysa sayfa yıllık fiyatla okunur kalır — sayı ekranda, boş kutu değil.

    "2 ay hediye" HESAPLANIR (bkz. _kur.php): panelden fiyat değişince rozet kendini düzeltir,
    kazanç bir aydan azsa hiç basılmaz.

    Vurgulu karttaki oran rozeti TEMSİLİDİR — bkz. site/parca/_temsili-veri.php.
--}}
@php
    $p = $sw['plan']['sipario'];
    $q = $sw['plan']['kurumsal'];
    // Alpine'in dönem anahtarında kullanacağı, sunucuda biçimlenmiş metinler.
    $donemMetin = [
        'yil' => [
            'rakam' => $fiyat['yillikAy'],
            'alt' => 'yıllık ödemede',
            'not' => 'Yılda bir kez '.$fiyat['yillikToplam'].' tahsil edilir · havale veya elden · KDV dahil',
        ],
        'ay' => [
            'rakam' => $fiyat['aylik'],
            'alt' => 'aylık ödemede',
            'not' => 'Her ay '.$fiyat['aylik'].' tahsil edilir · istediğiniz zaman iptal · KDV dahil',
        ],
    ];
    /*
     * "2 ay hediye" rozeti metnin İÇİNE giriyor ("Yıllık<span…>"). Blade yönergeyi yalnız kelime
     * sınırında tanır — "Yıllık@if(...)" ham metin olarak basılır, karşısındaki @endif ise derlenir
     * ve şablon sözdizimi hatası verir. O yüzden rozet burada kurulup tek parça basılıyor.
     */
    $hediyeRozet = $fiyat['hediyeAy'] > 0
        ? '<span class="donem-rzt">'.e($fiyat['hediyeAy'].' ay hediye').'</span>'
        : '';
@endphp
<section class="blm fiyat-hero" x-data="{ donem: 'yil', m: @js($donemMetin) }">
    <div class="kap">
        <div class="blm-bas fiyat-bas">
            <span class="blm-kulak mn"><i></i>Fiyatlandırma</span>
            <h1 class="h1">Tek plan, açık fiyat.<br>Büyüdükçe cezalandırmıyoruz.</h1>
            <p class="gvd b">Müşteri, sipariş ya da veri sınırı yok. Ne kadar çalışırsanız çalışın fiyat aynı kalır — sadece kaç kişinin kullandığı değişir.</p>
        </div>

        <div class="donem" role="group" aria-label="Ödeme dönemi">
            <button type="button" class="donem-b on" :class="{ on: donem === 'yil' }"
                @click="donem = 'yil'" :aria-pressed="donem === 'yil'" aria-pressed="true">
                Yıllık{!! $hediyeRozet !!}
            </button>
            <button type="button" class="donem-b" :class="{ on: donem === 'ay' }"
                @click="donem = 'ay'" :aria-pressed="donem === 'ay'" aria-pressed="false">Aylık</button>
        </div>

        <div class="plan-grid">
            <x-site.pano class="plan plan-vurgu" etiket="Standart plan" genis-ic>
                @if (! empty($tmsl['planRozet']))
                    <x-slot:sag>
                        <x-site.rozet tur="mor" nokta>{{ $tmsl['planRozet'] }}</x-site.rozet>
                    </x-slot:sag>
                @endif
                <div class="plan-bas">
                    <span class="h2">{{ $p['ad'] }}</span>
                    <p class="gvd">{{ $p['ozet'] }}</p>
                </div>
                <div class="plan-fiyat">
                    <span class="rakam" x-text="m[donem].rakam">{{ $donemMetin['yil']['rakam'] }}</span>
                    <span class="fo-donem">/ ay<br><small x-text="m[donem].alt">{{ $donemMetin['yil']['alt'] }}</small></span>
                </div>
                <p class="kucuk plan-not" x-text="m[donem].not">{{ $donemMetin['yil']['not'] }}</p>
                <ul class="plan-liste">
                    @foreach ($p['kapsam'] as $x)
                        <li>
                            <x-site.ikon ad="onay" boy="16" kalin="2.6" renk="var(--yesil)" />
                            <span><b>{{ $x['t'] }}</b>@if($x['a'])<small>{{ $x['a'] }}</small>@endif</span>
                        </li>
                    @endforeach
                </ul>
                <a class="dg dg-a tam" href="{{ route('subscription.register') }}">{{ $p['cta'] }}</a>
                <span class="kucuk fo-alt">{{ $p['ctaAlt'] }}</span>
            </x-site.pano>

            {{-- Kurumsal: self-servis satın alma YOK, CTA iletişime gider (tasarımın davranışı). --}}
            <x-site.pano class="plan" ince etiket="Çok şubeli" genis-ic>
                <div class="plan-bas">
                    <span class="h2">{{ $q['ad'] }}</span>
                    <p class="gvd">{{ $q['ozet'] }}</p>
                </div>
                <div class="plan-fiyat">
                    <span class="rakam kucuk-rakam">{{ $q['ozelFiyat'] }}</span>
                </div>
                <p class="kucuk plan-not">Şube ve kullanıcı sayısına göre belirlenir. Kendi sunucunuzda kurulum ve yerinde eğitim dahildir.</p>
                <ul class="plan-liste">
                    @foreach ($q['kapsam'] as $x)
                        <li>
                            <x-site.ikon ad="onay" boy="16" kalin="2.6" renk="var(--yesil)" />
                            <span><b>{{ $x['t'] }}</b>@if($x['a'])<small>{{ $x['a'] }}</small>@endif</span>
                        </li>
                    @endforeach
                </ul>
                <a class="dg dg-c tam" href="{{ route('site.iletisim') }}">{{ $q['cta'] }}</a>
                <span class="kucuk fo-alt">{{ $q['ctaAlt'] }}</span>
            </x-site.pano>
        </div>

        {{--
            Ek kurye notu KATALOĞA GÖRE yazıldı. Tasarım "99 ₺/ay" diyordu; katalogda (addon_packages)
            böyle bir kalem yok ve ek paket bir SÜRE değil KAPASİTE satışıdır — EkPaketServisi kotayı
            KALICI artırır, aylık yenilemez. Rakam ve periyot ikisi birden düzeltildi.
        --}}
        @if ($fiyat['ekKuryeKisa'] !== null)
            <div class="fiyat-ek">
                <x-site.kutu tur="mor" ikon="bilgi">
                    <b>Ek kurye hesabı {{ $fiyat['ekKuryeKisa'] }}.</b> Sipario planı {{ $fiyat['kurye'] }} kurye hesabı içerir; daha fazlası ek paketle eklenir. Aylık ücret değildir — tek seferlik ödersiniz, hesap hakkınız kalıcı olarak artar.
                </x-site.kutu>
            </div>
        @endif
    </div>
</section>
