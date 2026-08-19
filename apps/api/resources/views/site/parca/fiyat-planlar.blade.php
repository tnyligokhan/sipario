{{--
    Fiyatlandırma · hero + dönem anahtarı + TEK plan kartı (11-sw-fiyat.jsx · FiyatSayfa üst bloğu,
    DonemAnahtar, PlanKart).

    TEK PAKET (2026-08-05): tasarımın ikinci kartı ("Kurumsal · 1.499 ₺'den başlar") kaldırıldı —
    `plans` tablosu tek satırlıdır, Kurumsal diye satılan bir plan yoktur. Izgara `tek` değiştirici
    sınıfıyla tek sütuna düşer — kuralı `public/css/site.css` tanımlar.

    Dönem anahtarı Alpine ile. Sunucu YILLIK dönemi basar (tasarımın açılış durumu); JavaScript
    kapalıysa sayfa yıllık fiyatla okunur kalır — sayı ekranda, boş kutu değil.

    "2 ay hediye" HESAPLANIR (bkz. _kur.php): panelden fiyat değişince rozet kendini düzeltir,
    kazanç bir aydan azsa hiç basılmaz.
--}}
@php
    $p = $sw['plan']['sipario'];
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
{{-- `m` yükü `application/json` kanalıyla geçiyor: @js(dizi) `JSON.parse('…')` üretir, CSP
     değerlendiricisi `JSON`u çözemez — anahtar ölür ve Aylık'ta YILLIK rakam kalırdı (yanlış fiyat).
     Bkz. alpine.js başlığı 3. kural · donemAnahtar. --}}
<section class="blm fiyat-hero" x-data="donemAnahtar">
    <script type="application/json">@json($donemMetin)</script>
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

        <div class="plan-grid tek">
            <x-site.pano class="plan plan-vurgu" etiket="Tek plan" genis-ic>
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
                <a class="dg dg-a tam" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="fiyat-karti">{{ $p['cta'] }}</a>
                <span class="kucuk fo-alt">{{ $p['ctaAlt'] }}</span>
            </x-site.pano>
        </div>

        {{--
            Ek kurye notu KATALOĞA GÖRE yazılır (addon_packages · type=courier · aktif olanlar).
            Tasarım "99 ₺/ay" diyordu; katalogda böyle bir kalem yok ve ek paket bir SÜRE değil
            KAPASİTE satışıdır — EkPaketServisi kotayı KALICI artırır, aylık yenilemez. Rakam ve
            periyot ikisi birden düzeltildi. Katalog boşsa bölüm HİÇ basılmaz — fiyat uydurulmaz.
            Aynı paketleri hesap panelindeki "Ek paket" ekranı da aynı servisten okur.
        --}}
        @if (! empty($fiyat['kuryePaketleri']))
            <div class="fiyat-ek">
                <x-site.kutu tur="mor" ikon="bilgi">
                    <b>Plana {{ $fiyat['kurye'] }} kurye hesabı dahil.</b>
                    Daha fazlası ek paketle eklenir:
                    {{ collect($fiyat['kuryePaketleri'])->map(fn ($k) => '+'.$k['adet'].' kurye '.$k['fiyat'])->join(' · ') }}.
                    Aylık ücret değildir — tek seferlik ödersiniz, hesap hakkınız kalıcı olarak artar.
                </x-site.kutu>
            </div>
        @endif
    </div>
</section>
