{{--
    sipario.com.tr · HAKKIMIZDA — 2026-08-19'da eklendi, tasarım kaynağında YOKTU.

    ── NEDEN BU SAYFA GEREKLİ ───────────────────────────────────────────────────────────────
    Site, esnaftan yılda dört haneli bir ödeme istiyor ve karşısındaki kişi bunu bir telefon
    ekranından, kimseyle görüşmeden yapacak. Böyle bir kararın önündeki en büyük engel fiyat
    değil, GÜVEN: "bunlar kim, yarın kapanırlarsa defterim ne olacak?"

    Bu soru siteye hiçbir yerde sorulmuyordu. Üstelik güven boşluğu bu vardiyada BÜYÜDÜ: ana
    sayfadaki üç müşteri yorumu uydurma olduğu için kaldırıldı (DECISIONS 2026-08-19) ve
    yerlerine gerçek referans konamadı — ürün pilot aşamasında, henüz izin alınmış bir yorum
    yok. Yorumlar bir güven kaynağıydı (sahte de olsa); onları silip yerine hiçbir şey
    koymamak, sayfayı daha dürüst ama daha soğuk bırakırdı.

    Bu sayfanın işi o boşluğu SAHTE OLMAYAN bir şeyle doldurmak: kim olduğumuzu, neden
    yaptığımızı ve nerede olduğumuzu söylemek.

    ── NE YAZILMADI VE NEDEN ────────────────────────────────────────────────────────────────
    Kurucu adı, ekip fotoğrafı, "10 yıllık sektör tecrübesi", "20 yazılımcı", ofis adresi,
    kuruluş yılı — HİÇBİRİ. Bunları bilmiyorum ve uydurmak, aynı vardiyada uydurma müşteri
    yorumlarını silmiş olmakla açıkça çelişirdi.

    Ayrıca köşeli parantezli yer tutucu da KULLANILMADI: bu bir pazarlama sayfası ve
    `SiteIcerikTest` genel sayfalarda yer tutucuyu yasaklıyor (gerekçe: ziyaretçi "[Şirket
    unvanı]" görürse site yarım kalmış görünür). Sayfa, künye olmadan da doğru olan şeyler
    üzerine kuruldu; şirket kurulduğunda buraya unvan/adres eklemek bir cümle işidir.

    ── PİLOT AŞAMASINI SAKLAMAMAK BİR SATIŞ RİSKİ DEĞİL ─────────────────────────────────────
    "Yeniyiz" demek ilk bakışta zayıflık gibi durur. Ama alternatifi, büyük görünmeye çalışıp
    ilk destek aramasında yakalanmaktır — esnaf küçük bir ekibi arayıp sahibine ulaşmayı
    zaten sever. Dürüstlük burada satış argümanının kendisi.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

<x-layouts.site
    baslik="Hakkımızda · Sipario"
    aciklama="Sipario'yu kimler yapıyor, neden yaptık ve size ne söz veriyoruz. Küçük bir ekibiz, sahadaki bayilerle birlikte geliştiriyoruz.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush

    <section class="blm ic-hero">
        <div class="kap">
            <div class="blm-bas">
                <h1 class="h1 ic-h1">Biz kimiz?</h1>
                <p class="gvd b">Küçük bir ekibiz. Sipario'yu, defteri elinde tutan esnafın işini kolaylaştırsın diye yazıyoruz.</p>
            </div>
        </div>
    </section>

    <section class="blm kagit2">
        <div class="kap sss-kap">
            <div class="ys-b">
                <h2 class="h2">Neden yaptık?</h2>
                <p class="gvd">Su bayilerinde, tüpçülerde, manavlarda hep aynı manzarayı gördük: telefon çalıyor, karşıdaki kendini anlatıyor, esnaf bir yandan yazıyor. Akşam kasa tutmuyor. Kimin ne kadar borcu olduğunu bir tek defteri tutan kişi biliyor, o da izne çıkınca tahsilat duruyor.</p>
                <p class="gvd">Bunun için piyasada program vardı ama çoğu ya bilgisayara kurulan ağır muhasebe yazılımlarıydı ya da internet kesilince duran uygulamalar. Oysa tezgâhın arkasındakinin istediği şey basitti: telefon çaldığında kimin aradığını görmek, üç dokunuşta siparişi kaydetmek, akşam kasayı tutturmak.</p>
                <p class="gvd">Sipario tam bunu yapıyor. Fazlasını yapmıyor — muhasebe programı değil, e-fatura kesmiyor, beyanname doldurmuyor.</p>
            </div>

            {{--
                ⚠️ 2026-09-01'DE DÜZELTİLDİ. Bu bölüm "Sunucularımız da Türkiye'de. Bu bir tercih
                değil, baştan çizdiğimiz bir sınır" diyordu. Sunucu ölçüldü: Hostinger, Frankfurt
                (`srv1577146.hstgr.cloud`, AS47583) — yani cümle yanlıştı ve tam da bu sayfanın
                iddiasının (dürüstlük) altını oyuyordu. Kullanıcı kararı: Türkiye'de barındırma
                şartı kaldırıldı (maliyet). Yeni metin nerede olduğunu söylüyor ve KVKK'nın
                gerçekten sorduğu şeye — kimin erişebildiğine — cevap veriyor.
            --}}
            <div class="ys-b">
                <h2 class="h2">Nerede olduğumuz</h2>
                <p class="gvd">Ekip Türkiye'de. Sunucularımız Almanya'da, Frankfurt'ta duruyor — Avrupa Birliği veri koruma rejiminin geçerli olduğu bir veri merkezinde. Verileriniz KVKK kapsamında işleniyor; nereye ne gittiği <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">Aydınlatma Metni'nde</a> tek tek yazılı.</p>
                <p class="gvd">Önemli olan yalnız ülke değil, kimin görebildiği: her işletmenin verisi veritabanı düzeyinde ayrılmıştır, bir bayi diğerininkini teknik olarak göremez. Biz de göremeyiz — destek panelimizde iş verinizi değiştirme yetkisi yoktur ve bakılan her kayıt iz bırakır.</p>
                <p class="gvd">Desteğe de biz bakıyoruz. Yazdığınızda çağrı merkezi değil, ürünü yazan ekip cevap veriyor.</p>
            </div>

            <div class="ys-b">
                <h2 class="h2">Yeniyiz, saklamıyoruz</h2>
                <p class="gvd">Sipario yeni bir ürün. Şu an sahadaki bayilerle birlikte geliştiriyoruz; her hafta gelen geri bildirimle bir şeyler değişiyor. Size "binlerce işletme kullanıyor" demiyoruz — çünkü doğru olmaz.</p>
                <p class="gvd">Bunun sizin için iki anlamı var. Birincisi: söylediğiniz şey gerçekten dinleniyor, istediğiniz bir özellik haftalar içinde gelebiliyor. İkincisi: eksik bulduğunuz bir yer olursa bize söyleyin — büyük bir şirkete yazıyor gibi değil, sahibine söylüyor gibi olun.</p>
            </div>

            <div class="ys-b">
                <h2 class="h2">Size ne söz veriyoruz?</h2>
                <ul class="ys-liste">
                    <li><b>Defteriniz sizin.</b> Aboneliğiniz bitse bile kayıtlarınız silinmez. İstediğiniz an "verilerimi gönderin" deyin, Excel olarak yollayalım. Parayı tahsil etmek için verinizi rehin almayız.</li>
                    <li><b>Sürpriz ücret yok.</b> Ödediğiniz dönemin fiyatı sabittir. Yeni dönemde fiyat değişecekse en az 30 gün önce haber veririz.</li>
                    <li><b>Kendiliğinden para çekmeyiz.</b> Otomatik yenileme diye bir şey yok. Devam etmek istemezseniz hiçbir şey yapmanıza gerek kalmaz.</li>
                    <li><b>Veriniz satılmaz.</b> Müşteri listenizi kimseye vermeyiz, reklam için kullanmayız, yapay zekâ eğitiminde kullanmayız.</li>
                    <li><b>Bilmediğimizi bilmiyoruz deriz.</b> Yapamayacağımız bir şeyi "yaparız" demeyiz; uymuyorsa satmayız.</li>
                </ul>
            </div>

            <div class="ys-b">
                <h2 class="h2">Konuşalım</h2>
                <p class="gvd">İşletmenizi anlatın, Sipario size uyar mı dürüstçe söyleyelim. Sormak istediğiniz her şeyi sorabilirsiniz.</p>
                <div class="dg-grup" style="margin-top:18px">
                    <a class="dg dg-a" href="{{ route('site.iletisim') }}">Bize yazın<x-site.ikon ad="ok" boy="18" kalin="2.2" /></a>
                    <a class="dg dg-c" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="hakkimizda">{{ $fiyat['deneme'] }} gün ücretsiz deneyin</a>
                </div>
            </div>
        </div>
    </section>
</x-layouts.site>
