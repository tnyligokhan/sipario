{{--
    PlanYatay — TEK planın yatay levhası. 2026-09-01'de eklendi (kullanıcı kararı).

    ── NEDEN YATAY ──────────────────────────────────────────────────────────────────────────
    Kullanıcının sözü: *"Tek plan, tek fiyat kısmı da hoşuma gitmiyor. Zaten tek bir plan var
    ve oradaki tasarım yatay olabilir."*

    Eski kart, KARŞILAŞTIRMA için tasarlanmış bir plan kartıydı: dar sütun, fiyat üstte, altında
    dokuz satırlık dikey liste, en altta düğme. O biçim iki-üç kartın yan yana durduğu bir
    ızgarada anlamlıdır — göz sütunları karşılaştırır. Tek plan varken karşılaştıracak bir şey
    yok; kalan tek şey 560 piksele sıkıştırılmış, ekranı boyuna uzatan bir sütun ve iki yanında
    boş kâğıt. Yatay levha aynı bilgiyi ekranın kendi yönünde kuruyor:
      sol = KARAR (ad · fiyat · düğme) · sağ = KAPSAM (iki sütun liste)

    ── EK KURYE NOTU ARTIK BÖLÜMÜN ALTINDA DEĞİL, SATIRIN İÇİNDE ───────────────────────────
    Aynı kararın ikinci yarısı: *"…bu uyarıda gereksiz. Bu şekilde yapmak yerine içerisine göm
    ve üzerine gelindiği zaman bu çıksın."* Eski hâli fiyat bölümünün altında ayrı, mor zeminli
    bir bilgi kutusuydu — dört satırlık bir istisna, kararın hemen yanında, kimsenin sormadığı
    bir soruya cevap veriyordu. Not artık ait olduğu yerde: "N kurye hesabı" satırının üstüne
    gelince (ya da klavyeyle odaklanınca) açılıyor.

    ⚠️ İPUCU SAF CSS'TİR, JS DEĞİL. Site CSP altında çalışıyor ve `x-data` kurmadan da açılıp
    kapanmalı; ayrıca JavaScript yüklenmeden de bilgi ERİŞİLEBİLİR kalmalı — bu yüzden metin
    HTML'de duruyor ve `aria-describedby` ile düğmeye bağlı. Düğme `<button>` çünkü dokunmatik
    ekranda `:hover` yoktur; parmakla dokunmak `:focus` üretir ve kutu açılır.

    Props:
      plan   — $sw['plan']['sipario'] (ad · ozet · cta · ctaAlt · kapsam[])
      fiyat  — _kur.php'nin 'fiyat' bloğu
      kimlik — sayfada tekil ön ek; ipucu id'si buradan türer (aynı bileşen iki sayfada var)
      donem  — dönem anahtarı istenmiyorsa null; isteniyorsa fiyat-planlar'daki $donemMetin dizisi
--}}
@props(['plan', 'fiyat', 'kimlik', 'donem' => null, 'etiket' => 'Tek plan'])
@php
    $ipucuId = $kimlik.'-kurye-ipucu';
    $kuryeNotu = empty($fiyat['kuryePaketleri'])
        ? null
        : 'Ek paketle kurye hakkınızı artırabilirsiniz: '
            .collect($fiyat['kuryePaketleri'])->map(fn ($k) => '+'.$k['adet'].' kurye '.$k['fiyat'])->join(' · ')
            .'. Tek seferlik ödenir, hesap hakkınız kalıcı olarak artar — aylık ücret değildir.';
@endphp
<div class="yplan-sarma" @if($donem) x-data="donemAnahtar" @endif>
    @if($donem)
        {{-- Yük `application/json` kanalıyla: @js(dizi) `JSON.parse('…')` üretir, CSP
             değerlendiricisi `JSON`u çözemez ve anahtar ölür (Aylık'ta yıllık rakam kalırdı). --}}
        <script type="application/json">@json($donem)</script>
        <div class="donem" role="group" aria-label="Ödeme dönemi">
            <button type="button" class="donem-b on" :class="{ on: donem === 'yil' }"
                @click="donem = 'yil'" :aria-pressed="donem === 'yil'" aria-pressed="true">
                Yıllık{!! $fiyat['hediyeAy'] > 0 ? '<span class="donem-rzt">'.e($fiyat['hediyeAy'].' ay hediye').'</span>' : '' !!}
            </button>
            <button type="button" class="donem-b" :class="{ on: donem === 'ay' }"
                @click="donem = 'ay'" :aria-pressed="donem === 'ay'" aria-pressed="false">Aylık</button>
        </div>
    @endif

    <x-site.pano class="yplan" :etiket="$etiket" genis-ic>
        <div class="yplan-ic">
            <div class="yplan-karar">
                <div class="yplan-bas">
                    <span class="h2">{{ $plan['ad'] }}</span>
                    <p class="gvd">{{ $plan['ozet'] }}</p>
                </div>
                <div class="yplan-fiyat">
                    <span class="rakam" @if($donem) x-text="m[donem].rakam" @endif>{{ $donem ? $donem['yil']['rakam'] : $fiyat['yillikAy'] }}</span>
                    <span class="fo-donem">/ ay<br><small @if($donem) x-text="m[donem].alt" @endif>{{ $donem ? $donem['yil']['alt'] : 'yıllık ödemede' }}</small></span>
                </div>
                <p class="kucuk yplan-not" @if($donem) x-text="m[donem].not" @endif>{{ $donem
                    ? $donem['yil']['not']
                    : 'Aylık ödemede '.$fiyat['aylik'].'/ay · yıllık '.$fiyat['yillikToplam'].' · havale veya elden · KDV dahil' }}</p>
                <a class="dg dg-a tam" href="{{ route('subscription.register') }}"
                    data-olcum="sipario_deneme_tik" data-olcum-etiket="fiyat-karti">{{ $plan['cta'] }}</a>
                <span class="kucuk yplan-alt">{{ $plan['ctaAlt'] }}</span>
            </div>

            <ul class="yplan-liste">
                @foreach ($plan['kapsam'] as $x)
                    <li>
                        <x-site.ikon ad="onay" boy="16" kalin="2.6" renk="var(--yesil)" />
                        <span>
                            <b>{{ $x['t'] }}@if(($x['k'] ?? null) === 'kurye' && $kuryeNotu)<span class="ipucu"><button type="button" class="ipucu-d" aria-describedby="{{ $ipucuId }}"><x-site.ikon ad="bilgi" boy="15" kalin="2.2" /><span class="gizli">Ek kurye paketleri hakkında</span></button><span class="ipucu-k" id="{{ $ipucuId }}" role="tooltip">{{ $kuryeNotu }}</span></span>@endif</b>
                            @if($x['a'])<small>{{ $x['a'] }}</small>@endif
                        </span>
                    </li>
                @endforeach
            </ul>
        </div>
    </x-site.pano>
</div>
