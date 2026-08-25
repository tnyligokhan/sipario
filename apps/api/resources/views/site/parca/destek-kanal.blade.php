{{--
    Destek · iletişim kanalları (15-sw-destek.jsx · DestekSayfa üst bloğu).

    YER TUTUCU KANAL HİÇ BASILMAZ (2026-08-05): eskiden gerçek değeri olmayan kanal "[Telefon]"
    diye düz metin basılıyordu — bağlantısız ama ekranda. Artık liste `_veri.php`de süzülüyor
    (iletişim sayfası ve alt bilgiyle aynı ilke), yani buraya YALNIZ gerçek kanallar geliyor ve
    kart sayısı 1-3 arasında DEĞİŞKEN. İki sonucu var, ikisi de aşağıda karşılandı:
      · Izgara `repeat(3,1fr)` sabitti; üçten az kartta `az` sınıfı devreye giriyor (CSS: `stil`).
      · Giriş cümlesi telefon vaat ediyordu ("aynı numara", "ilk aramada"). Telefon kanalı
        listede yoksa o cümle YALAN olurdu; metin kanal listesine göre seçiliyor. Gerçek numara
        config'e girdiği gün hem kart hem tasarımın kendi cümlesi kendiliğinden geri gelir.
--}}
@php($telefonVar = collect($sw['kanal'])->contains(fn (array $k) => $k['ik'] === 'telefon'))
<section class="blm kisa">
    <div class="kap">
        <div class="blm-bas">
            <span class="blm-kulak mn"><i></i>Destek</span>
            <h1 class="h1">Takıldığınız yerde<br>insan var.</h1>
            <p class="gvd b">{{ $telefonVar
                ? 'Telefonu bot açmıyor. Aynı ekip, aynı numara — çoğu soru ilk aramada çözülüyor.'
                : 'Bot yok, otomatik yanıt yok. Yazdığınız gün aynı ekip size dönüyor.' }}</p>
        </div>
        @if (! empty($sw['kanal']))
        <div @class(['kanal-grid', 'az' => count($sw['kanal']) < 3])>
            @foreach ($sw['kanal'] as $k)
                <x-site.pano class="kanal" :ince="! $loop->first">
                    <span class="kanal-ik"><x-site.ikon :ad="$k['ik']" boy="21" kalin="2" renk="var(--mor)" /></span>
                    <span class="mn">{{ $k['t'] }}</span>
                    {{--
                        Telefon ve WhatsApp tıklamaları ÖLÇÜLÜR (2026-08-19). Bu ürünün satışı
                        birebir yürüyor; "kaç kişi siteden numarayı tıkladı" sorusu, sayfa
                        görüntülemeden daha anlamlı bir dönüşüm sinyali. Olay adı ikonun
                        adından türüyor — kanal listesi büyüdüğünde burada değişiklik gerekmez.
                    --}}
                    <b class="h3 kanal-v">
                        @if ($k['href'])<a href="{{ $k['href'] }}"
                            @if(in_array($k['ik'], ['telefon', 'sohbet'], true))
                                data-olcum="{{ $k['ik'] === 'telefon' ? 'sipario_telefon_tik' : 'sipario_whatsapp_tik' }}"
                                data-olcum-etiket="destek-sayfasi"
                            @endif
                        >{{ $k['deger'] }}</a>@else{{ $k['deger'] }}@endif
                    </b>
                    <p class="kucuk">{{ $k['a'] }}</p>
                </x-site.pano>
            @endforeach
        </div>
        @endif
    </div>
</section>
