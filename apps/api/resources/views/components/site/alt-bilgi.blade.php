{{--
    AltBilgi — sayfa altbilgisi. Rota adları henüz açılmamışsa bağlantı atlanır.

    `oturum`: bayi oturumu açıksa "Hesap" sütunu üye bağlantılarını gösterir. Üst menüyle aynı
    sözleşme — bu bileşen kimlik doğrulamayı KENDİSİ sorgulamaz, layout geçer (gerekçe:
    components/layouts/site.blade.php; `Auth::check()` genel sayfalarda RLS yüzünden yalan söyler).

    ── BAĞLANTI SÖZLEŞMESİ (2026-08-05) ─────────────────────────────────────────────────────────
    Her satır GERÇEK ve BENZERSİZ bir hedefe gider. Bu kural bir kusurdan doğdu: alt bilgide
    farklı adlar taşıyan bağlantılar aynı sayfaya çıkıyordu — "Kurulum" ve "Özellikler" ikisi de
    /ozellikler'e, "Sürüm notları" ile "Sık sorulanlar" ikisi de /destek'e, "Demo talebi" ile
    "İletişim" ikisi de /iletisim'e. Kullanıcı için bu bir bağlantı değil TUZAKTIR: yeni bir şey
    vaat eder, gördüğü sayfaya geri atar. Yer doldurmak için satır EKLENMEZ; sütunların satır
    sayısı eşit olmak zorunda değildir (ızgara `repeat(4,1fr)`, hücreler üstten hizalı).

    Yeni bir satır eklemenin ŞARTI: kendi rotası + kendi görünümü olan bir hedef. Sınıfı/görünümü
    olmayan rota açmak depoyu kırar (kayıtlı tuzak) — önce sayfa, sonra bağlantı.
--}}
@props(['oturum' => false])
@php
    // Üçüncü öge çapa (fragment); boşsa sayfanın kendisine gider.
    $urun = [
        ['Özellikler', 'site.ozellikler', ''],
        /*
         * FİYAT BAĞLANTISI /fiyatlar'a DEĞİL, ana sayfanın fiyat özetine gider (2026-08-05,
         * `fiyat` ajanıyla teyitleşilerek). Önce alt bilgide /fiyatlar'ı bırakmıştım; ajanın
         * ölçümü kararı değiştirdi: sayfa `noindex` ile arama motorlarına kapatıldı, ana
         * sayfadaki "Paketleri karşılaştır" kaldırıldı ve "Fiyatlara bak" düğmesi de bu çapaya
         * çevrildi. Yani alt bilgi, kullanıcının "göstermeyelim" dediği sayfaya işaret eden TEK
         * yer olarak kalıyordu — kararın her yerde uygulanıp yalnız burada delinmesi olurdu.
         *
         * Fiyat bilgisi KAYBOLMUYOR: `#fiyat` çapası ana sayfanın fiyat özeti bölümüdür
         * (site/parca/ana-fiyat-ozet.blade.php, `id="fiyat"` — ölçüldü). Yani bağlantı gerçek
         * fiyatın göründüğü yere iniyor. `/fiyatlar` rotası ve sayfası DURUYOR; birebir satışta
         * adresi doğrudan paylaşılabilir, sadece siteden kendini göstermiyor.
         */
        // "Fiyatlandırma" → "Fiyat": aynı yere gidiyor, iki hece kısa ve daha sık kullanılan
        // kelime. Alt bilgi sütunları tarama içindir; uzun kelime taramayı yavaşlatır.
        ['Fiyat', 'site.ana', '#fiyat'],
    ];
    $destek = [
        // Tek satır: /destek sayfası zaten "Destek ve sık sorulan sorular" — kanallar ve SSS aynı
        // sayfada. İki ayrı ad vermek (Yardım merkezi + Sık sorulanlar) iki sayfa vaat ediyordu.
        ['Destek ve SSS', 'site.destek'],
        // Üst menüden buraya indi (kullanıcı kararı 2026-08-05).
        ['İletişim', 'site.iletisim'],
        // 2026-08-19: "Biz kimiz" sayfası. Alt bilgideki yeri bilinçli — üst menüye koymak
        // menüyü şişirirdi (menü keşif aracıdır, site haritası değil; 2026-08-05 kararı), ama
        // "bunlar kim" sorusu para ödemeden önce sorulan bir sorudur ve bir yerden erişilmeli.
        ['Biz kimiz', 'site.hakkimizda'],
    ];
    // Üçüncü öge route parametresidir (yoksa boş dizi) — `Hesap` sütununda sekme anahtarı taşır.
    $hesap = $oturum
        ? [
            ['Hesabım', 'site.hesap', []],
            // `?bolum=` Hesap ekranının GERÇEK sekme anahtarıdır (App\Livewire\Site\Hesap::BOLUMLER,
            // mount() kapalı listeye karşı doğrular) — yani bu üç satır üç ayrı ekrana gider,
            // aynı sayfanın üç adı değil.
            ['Abonelik', 'site.hesap', ['bolum' => 'abonelik']],
            ['Faturalar', 'site.hesap', ['bolum' => 'fatura']],
            ['Hesap ve veri silme', 'account.deletion', []],
        ]
        : [
            ['Giriş yap', 'subscription.login', []],
            ['İşletme aç', 'subscription.register', []],
            // Google Play, hesap sistemi olan uygulamalar için silme talebinin GENEL ERİŞİLEBİLİR
            // bir adreste durmasını şart koşar. Sayfa vardı ama siteden hiçbir yere bağlı değildi
            // (2026-08-05'te ölçüldü: `account.deletion` görünümlerde sıfır referans) — yalnız
            // data-safety formundaki URL'i bilen bulabiliyordu.
            ['Hesap ve veri silme', 'account.deletion', []],
        ];
    /*
     * ── YASAL SÜTUN: HEPSİ DEĞİL, GİRİŞ KAPILARI (2026-08-19) ─────────────────────────────
     * Belge sayısı 5'ten 10'a çıktı (kullanım koşulları, gizlilik politikası, açık rıza, veri
     * işleyen eki, başvuru formu eklendi). Onu birden buraya dizmek, alt bilgiyi tek sütunlu
     * bir mevzuat listesine çevirirdi ve ızgaranın diğer üç sütunuyla oranı bozulurdu.
     *
     * Çözüm listelemek değil, YAPIYA GÜVENMEK: her yasal belge sayfasının SOL SÜTUNU on
     * belgenin tamamını taşır (legal/show.blade.php · ys-nav). Yani buradaki herhangi bir
     * bağlantı, diğer dokuzuna bir tık uzaklıktadır. Aşağıdaki altı satır, mevzuatın "kolay
     * erişilebilir olsun" dediği belgelerdir; kalan dördü türev/başvuru belgesidir.
     *
     * ⚠️ İKİZ HEDEF YASAĞI (SiteGezinmeTest kilitliyor): her satır farklı bir slug'a gider.
     */
    $yasal = [
        ['Mesafeli satış sözleşmesi', 'legal.show', 'mesafeli-satis'],
        // Ön bilgilendirme formu mevzuat gereği mesafeli satışın AYRILMAZ ekidir (sözleşmenin 14.
        // maddesi onu ek olarak sayar) ve belge zaten vardı; alt bilgide yoktu, yani ödeme akışı
        // dışından erişilemiyordu.
        ['Ön bilgilendirme formu', 'legal.show', 'on-bilgilendirme'],
        ['İptal ve iade', 'legal.show', 'iptal-iade'],
        ['Kullanım koşulları', 'legal.show', 'kullanim-kosullari'],
        ['Gizlilik ve KVKK', 'legal.show', 'kvkk-aydinlatma'],
        ['Çerez politikası', 'legal.show', 'cerez-politikasi'],
    ];
    // Künye tek kaynaktan: config('subscription.company') — ödeme ekranı, hesap paneli ve
    // mesafeli satış sözleşmesi de aynı bloğu okur. Alt bilgide artık yalnız telif satırında
    // kullanılıyor (aşağıdaki `alt-kunye` notuna bak).
    $sirket = config('subscription.company');
    /*
     * Telif satırındaki son yer tutucu da kapatıldı (2026-08-05). Künye bloğu kalkınca sayfada
     * görünen TEK köşeli parantez "© 2026 [Şirket unvanı]." kalmıştı — kaldırılan dört kutuyla
     * aynı türden kırıklık. Şirket unvanı hâlâ yer tutucuyken markaya düşülüyor: "Sipario" bir
     * varsayım değil, verilmiş karardır (BRIEF: "İsim: Sipario", domain alındı, marka başvurusu
     * süreçte) — uydurma bir tüzel kişilik unvanı basmıyoruz. Unvan config'te gerçek değerle
     * dolduğu an bu satır kendiliğinden gerçek unvana döner; kod değişmez.
     */
    $telifAdi = str_starts_with((string) $sirket['title'], '[') ? 'Sipario' : $sirket['title'];
@endphp
<footer class="alt gece">
    <div class="kap">
        <div class="alt-ust">
            <div class="alt-marka">
                <x-site.marka boy="38" koyu />
                <p class="alt-slogan">Telefon çaldığında müşteriniz ekranda. Bayiler ve esnaf için sipariş, veresiye ve kurye defteri.</p>
                {{--
                    "Tüm sistemler çalışıyor" ROZETİ KALDIRILDI (2026-08-19). İki sebep:

                    1. ANLAMSIZ. Bu, geliştiricilerin durum sayfalarından (status page) gelen bir
                       kalıptır ve teknik bir kitleye hitap eder. Su bayii "sistemler" diye bir
                       şey düşünmüyor; okuduğunda ya hiçbir şey anlamıyor ya da aklına "demek ki
                       bazen çalışmıyor" geliyor.
                    2. KANITSIZ. Rozet YEŞİL SABİTTİ — hiçbir sağlık kontrolüne bağlı değildi.
                       Sunucu tamamen çökse ve bu sayfa yine de basılsa "tüm sistemler çalışıyor"
                       demeye devam ederdi. Gerçek bir durum sayfası olmadan bu rozet bir ölçüm
                       değil, bir dekordur.

                    "Veriler Türkiye'de" DURUYOR: doğrulanabilir bir olgu ve esnafın gerçekten
                    önemsediği bir şey.
                --}}
                <div class="alt-rzt">
                    <x-site.rozet tur="notr">Veriler Türkiye'de</x-site.rozet>
                </div>
            </div>
            <div class="alt-baglanti">
                <div class="alt-sutun">
                    <span class="mn">Ürün</span>
                    @foreach($urun as [$etiket, $ad, $capa])
                        @if(Route::has($ad))<a href="{{ route($ad).$capa }}">{{ $etiket }}</a>@endif
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
                    @foreach($hesap as [$etiket, $ad, $par])
                        @if(Route::has($ad))<a href="{{ route($ad, $par) }}">{{ $etiket }}</a>@endif
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
        {{--
            ── `alt-kunye` KALDIRILDI (2026-08-05, kullanıcı kararı) ────────────────────────────
            Buradaki dört kutu (Ünvan / Kayıt / İletişim / Ödeme) sitenin görünen yüzünde DÖRT
            KIRIK KUTU basıyordu: `config('subscription.company')` değerlerinin hepsi hâlâ
            "[Şirket unvanı]", "[MERSİS no]" gibi köşeli parantezli yer tutucu. Yer tutucuyu
            gizlemek yerine bloğun tamamı kalktı — gerçek künye gelene kadar burada gösterilecek
            bir şey yok.

            MEVZUAT KARŞILIĞI KAPALI, ÖLÇÜLDÜ: satıcı künyesi (unvan, açık adres, MERSİS, KEP,
            telefon, e-posta) mesafeli satış mevzuatı gereği erişilebilir kalmak zorundadır ve
            iki ayrı belgede duruyor — `legal/docs/mesafeli-satis.blade.php` madde 1 "Taraflar"
            ve `legal/docs/on-bilgilendirme.blade.php` "Satıcı bilgileri". İkisi de yukarıdaki
            Yasal sütunundan tek tıkla açılıyor (2026-08-05 ölçümü: /sozlesme/mesafeli-satis ve
            /sozlesme/on-bilgilendirme → HTTP 200).

            DİKKAT — İKİ AYRI KAYNAK: alt bilgi config'ten okuyordu, hukuk belgeleri ise künyeyi
            DÜZ METİN yer tutucu olarak taşıyor. Gerçek künye geldiği gün config'i doldurmak
            YETMEZ; iki belgedeki köşeli parantezler de elle doldurulmalıdır.

            Künyenin alt bilgiye geri konup konmayacağı (gerçek değerlerle) KULLANICI KARARIDIR.
        --}}
        <div class="alt-son">
            <span class="kucuk">© {{ date('Y') }} {{ $telifAdi }}. Tüm hakları saklıdır.</span>
            {{--
                "Rakamlar örnektir" NOTU KALDIRILDI (2026-08-19) — ve bu, notu görmezden gelmek
                DEĞİL, notun sebebini ortadan kaldırmaktır.

                Not, sitedeki kullanım sayılarının ve müşteri yorumlarının TEMSİLİ (uydurma)
                olmasından doğmuştu: "1.240 işletme", "%31 daha az kayıp", isimli üç bayi
                yorumu. Bir dipnotla dürüst olmaya çalışıyordu ama olamıyordu — ziyaretçi
                yorumları okuyup notu okumuyor, hatta not TAM DA yorumların gerçek sanılacağını
                kabul ettiği için yazılmıştı.

                Bu vardiyada uydurma veri siteden ÇIKARILDI (site/parca/_temsili-veri.php artık
                boş dizi döndürüyor, ilgili bölümler sayfadan düşüyor). Uydurma rakam kalmayınca
                "rakamlar örnektir" cümlesinin işaret edeceği bir şey de kalmadı; bırakılsaydı
                bu kez KENDİSİ yanlış olurdu — sayfada örnek rakam yok.

                Yerine destek saati kaldı: ziyaretçinin alt bilgide gerçekten arayacağı bilgi.
            --}}
            <span class="kucuk">Destek: {{ $sirket['hours'] }}</span>
            {{--
                Çerez tercihi geri alma yolu — tercih penceresini açar (public/js/cerez.js).
                `<button>` bilerek — `<a href="#">` olsaydı "alt bilgideki her bağlantı benzersiz
                bir hedefe gider" sözleşmesine sahte bir hedefle girerdi (SiteGezinmeTest).

                Koşul ENVANTERDEN sorulur, doğrudan ölçüm ayarından değil (2026-08-28): rızaya
                bağlı hiçbir kategori yoksa değiştirilecek bir tercih de yoktur ve düğme
                ziyaretçiyi yanıltırdı. Yarın ölçüm dışında bir kategori eklenirse bu satır
                kendiliğinden doğru kalır.
            --}}
            @if ((new \App\Support\Cerez\CerezEnvanteri)->rizaGerekiyorMu())
                <button type="button" class="kucuk alt-cerez" data-cerez-ac>Çerez tercihleri</button>
            @endif
        </div>
    </div>
</footer>
