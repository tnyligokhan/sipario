{{--
    Destek · iletişim kanalları + "yardım nasıl geliyor" bloğu.

    ── ÜÇ EŞİT KART YERİNE İKİ BÖLGE (2026-09-01, kullanıcı kararı) ────────────────────────
    Kullanıcının sözü: *"Destek sayfasında sadece eposta adresi var."*

    Gördüğü şey doğruydu ve sebebi tasarım değil VERİYDİ: künyede gerçek bir telefon numarası
    yok, WhatsApp anahtarı hiç yok. Kanal listesi yer tutucuyu süzüyor (bkz. _veri.php), yani
    üç sütunluk ızgara tek kartla dolduruluyor ve sayfa "destek diye bir şey yok" gibi görünüyordu.

    Numara UYDURULMADI (kullanıcı kararı: "numara yok, sayfayı kanalsız tasarla"). Bunun yerine
    bölüm iki bölgeye ayrıldı:
      · SOL — gerçek kanallar. Bugün tek satır (e-posta), yarın numara girildiği gün üç satır.
        Liste bir ızgara değil satır yığını olduğu için kart sayısı değiştiğinde yerleşim
        BOZULMUYOR — eski `repeat(3,1fr)` + `.az` düzeltmesi tam da bu yüzden vardı.
      · SAĞ — "kanal" değil TAAHHÜT: kurulumu kim yapıyor, listeyi kim giriyor, ne kadar sürede
        dönülüyor. Ziyaretçinin "bozulursa kim bakacak" sorusunun asıl cevabı burada; bir telefon
        numarası o soruyu tek başına zaten cevaplamıyordu.

    Giriş cümlesi hâlâ kanal listesine bağlı: telefon yoksa arama vaat etmiyor (SiteIcerikTest
    iki yönü de kilitliyor).
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

        <div class="dst-ic">
            @if (! empty($sw['kanal']))
                <x-site.pano class="dst-kanal" etiket="Bize ulaşın" genis-ic>
                    <ul class="dst-liste">
                        @foreach ($sw['kanal'] as $k)
                            <li>
                                <span class="dst-ik"><x-site.ikon :ad="$k['ik']" boy="20" kalin="2" renk="var(--mor)" /></span>
                                <span class="dst-deger">
                                    <span class="mn">{{ $k['t'] }}</span>
                                    {{--
                                        Telefon ve WhatsApp tıklamaları ÖLÇÜLÜR (2026-08-19). Bu ürünün satışı
                                        birebir yürüyor; "kaç kişi siteden numarayı tıkladı" sorusu, sayfa
                                        görüntülemeden daha anlamlı bir dönüşüm sinyali. Olay adı ikonun
                                        adından türüyor — kanal listesi büyüdüğünde burada değişiklik gerekmez.
                                    --}}
                                    <b class="h3">
                                        @if ($k['href'])<a href="{{ $k['href'] }}"
                                            @if(in_array($k['ik'], ['telefon', 'sohbet'], true))
                                                data-olcum="{{ $k['ik'] === 'telefon' ? 'sipario_telefon_tik' : 'sipario_whatsapp_tik' }}"
                                                data-olcum-etiket="destek-sayfasi"
                                            @endif
                                        >{{ $k['deger'] }}</a>@else{{ $k['deger'] }}@endif
                                    </b>
                                    <span class="kucuk">{{ $k['a'] }}</span>
                                </span>
                            </li>
                        @endforeach
                    </ul>
                </x-site.pano>
            @endif

            <ul class="dst-soz">
                @foreach ([
                    ['ayar', 'Kurulumu birlikte yapıyoruz', 'Uzaktan ve ücretsiz. Kimsenin dükkâna gelmesi gerekmiyor.'],
                    ['musteriler', 'Müşteri listenizi biz giriyoruz', 'Excel, telefon rehberi ya da defterin fotoğrafı — nasıl duruyorsa gönderin. Açık veresiye bakiyeleri de taşınır.'],
                    ['saat', 'Aynı gün yanıt', 'Hafta içi 09:00–19:00 arası bakıyoruz; gece gelen sabah cevaplanır.'],
                ] as [$ik, $baslik, $metin])
                    <li>
                        <span class="dst-soz-ik"><x-site.ikon :ad="$ik" boy="18" kalin="2" renk="var(--mor)" /></span>
                        <span>
                            <b class="h4">{{ $baslik }}</b>
                            <span class="kucuk">{{ $metin }}</span>
                        </span>
                    </li>
                @endforeach
            </ul>
        </div>
    </div>
</section>
