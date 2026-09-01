{{--
    sipario.com.tr · HAKKIMIZDA

    Bu sayfanın işi tek bir soruyu cevaplamak: "bunlar kim, yarın kapanırlarsa defterim ne olacak?"
    Ürün ödemeyi kimseyle görüşmeden isteyen bir üründür; o soru sorulmadan para ödenmiyor.

    ⚠️ UYDURULMAYAN ŞEYLER: kurucu adı, ekip fotoğrafı, "10 yıllık tecrübe", çalışan sayısı,
    kuruluş yılı, ofis adresi, müşteri sayısı. Hiçbiri bilinmiyor ve uydurulmuş bir "hakkımızda"
    tam da güven kazanmaya çalıştığı yerde güveni bitirir. Sayfa yalnız doğrulanabilir şeyler
    üzerine kuruldu; şirket künyesi netleştiğinde buraya eklenecek olan bir cümlelik iştir.

    Yerleşim: hero → neden yaptık (iki sütun anlatı) → sözler (kart ızgarası) → künye şeridi → CTA.
    Hukuk belgesi görünümlü `.ys-b` blokları KULLANILMIYOR: burası bir pazarlama sayfası, sözleşme
    değil.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);

    $sozler = [
        ['indir', 'Defteriniz sizin', 'Aboneliğiniz bitse bile kayıtlarınız silinmez. “Verilerimi gönderin” deyin, Excel olarak yollayalım. Tahsilat için verinizi rehin almayız.'],
        ['para', 'Sürpriz ücret yok', 'Ödediğiniz dönemin fiyatı sabittir. Yeni dönemde fiyat değişecekse en az 30 gün önce haber veririz.'],
        ['kart', 'Kendiliğinden para çekmeyiz', 'Otomatik yenileme diye bir şey yok. Devam etmek istemezseniz hiçbir şey yapmanız gerekmez.'],
        ['kalkan', 'Veriniz satılmaz', 'Müşteri listenizi kimseye vermeyiz, reklam için kullanmayız, yapay zekâ eğitiminde kullanmayız.'],
        ['soru', 'Bilmediğimizi bilmiyoruz deriz', 'Yapamayacağımız bir şeye “yaparız” demeyiz. İşinize uymuyorsa satmayız.'],
        ['kulaklik', 'Cevabı yazan kişi ürünü yazan kişi', 'Çağrı merkezi yok. Yazdığınızda ürünü geliştiren ekip okuyor.'],
    ];

    $kunyeSerit = [
        ['Ekip', 'Türkiye'],
        ['Sunucular', 'Almanya · Frankfurt'],
        ['Ürünün yaşı', 'Yeni — sahada geliştiriliyor'],
        ['Destek', 'Hafta içi 09:00 – 19:00'],
    ];
@endphp

<x-layouts.site
    baslik="Hakkımızda | Sipario"
    aciklama="Sipario'yu kimler yapıyor, neden yaptık ve size ne söz veriyoruz.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush

    <section class="blm kisa hk-hero">
        <div class="kap hk-hero-ic">
            <span class="blm-kulak mn"><i></i>Hakkımızda</span>
            <h1 class="h1">Küçük bir ekibiz ve bunu saklamıyoruz.</h1>
            <p class="gvd b hk-lead">Sipario'yu, siparişi telefondan alıp kapıya gönderen işletmelerin işini kolaylaştırsın diye yazıyoruz. Başka bir işimiz yok.</p>
        </div>
    </section>

    <section class="blm kagit2">
        <div class="kap hk-neden">
            <div class="hk-neden-bas">
                <h2 class="h1">Neden yaptık?</h2>
            </div>
            <div class="hk-neden-metin">
                <p class="gvd b">Paket servisi yapan yerlerde hep aynı manzarayı gördük: telefon çalıyor, karşıdaki kendini baştan anlatıyor, biri bir kâğıda yazıyor. Akşam kasa tutmuyor. Kimin ne kadar borcu olduğunu yalnız defteri tutan kişi biliyor — o kişi izne çıkınca tahsilat da izne çıkıyor.</p>
                <p class="gvd">Piyasada program vardı ama çoğu ya bilgisayara kurulan ağır muhasebe yazılımlarıydı ya da internet kesilince duran uygulamalar. Oysa istenen şey basitti: telefon çaldığında kimin aradığını görmek, üç dokunuşta siparişi kaydetmek, kuryeyi doğru sıraya sokmak, akşam kasayı tutturmak.</p>
                <p class="gvd">Sipario tam bunu yapıyor. Fazlasını yapmıyor: muhasebe programı değil, e-fatura kesmiyor, beyanname doldurmuyor, yazar kasayla konuşmuyor.</p>
            </div>
        </div>
    </section>

    <section class="blm">
        <div class="kap">
            <x-site.blm-bas baslik="Size ne söz veriyoruz?"
                aciklama="Altısı da yazılı: sözleşmede, kullanım koşullarında ya da ürünün davranışında karşılığı var." />
            <div class="hk-soz-grid">
                @foreach ($sozler as [$ik, $baslik, $metin])
                    <div class="hk-soz">
                        <span class="hk-soz-ik"><x-site.ikon :ad="$ik" boy="20" kalin="1.9" renk="var(--mor)" /></span>
                        <h3 class="h4">{{ $baslik }}</h3>
                        <p class="kucuk">{{ $metin }}</p>
                    </div>
                @endforeach
            </div>
        </div>
    </section>

    <section class="blm kisa kagit2">
        <div class="kap">
            <dl class="hk-kunye">
                @foreach ($kunyeSerit as [$etiket, $deger])
                    <div>
                        <dt class="mn">{{ $etiket }}</dt>
                        <dd class="h4">{{ $deger }}</dd>
                    </div>
                @endforeach
            </dl>
            <p class="kucuk hk-kunye-not">Verilerinizin nerede tutulduğu, nereye ne gittiği ve kimin görebildiği <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">Aydınlatma Metni'nde</a> tek tek yazılı.</p>
        </div>
    </section>

    <section class="blm">
        <div class="kap hk-son">
            <div>
                <h2 class="h1">Yeni bir ürünüz. Bu sizin lehinize.</h2>
                <p class="gvd b">Size “binlerce işletme kullanıyor” demiyoruz, çünkü doğru olmaz. Bunun karşılığında söylediğiniz şey gerçekten dinleniyor: istediğiniz bir özellik haftalar içinde gelebiliyor, eksik bulduğunuz yeri büyük bir şirkete değil sahibine söylüyorsunuz.</p>
            </div>
            <div class="dg-grup">
                <a class="dg dg-a dev" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="hakkimizda">{{ $fiyat['deneme'] }} gün ücretsiz deneyin<x-site.ikon ad="ok" boy="19" kalin="2.2" /></a>
                <a class="dg dg-c dev" href="{{ route('site.iletisim') }}">Önce bir konuşalım</a>
            </div>
        </div>
    </section>
</x-layouts.site>
